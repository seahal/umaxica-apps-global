# typed: false
# frozen_string_literal: true

class WithdrawalLifecycle
  RECOVERY_PERIOD = Withdrawable::WITHDRAWAL_RECOVERY_PERIOD

  def self.start!(actor:, current_session_public_id: nil, request: nil)
    new(actor:, current_session_public_id:, request:).start!
  end

  def self.suspend!(actor:, current_session_public_id: nil, request: nil)
    new(actor:, current_session_public_id:, request:).suspend!
  end

  def self.recover!(actor:, request: nil)
    new(actor:, request:).recover!
  end

  def self.terminate!(actor:, request: nil)
    new(actor:, request:).terminate!
  end

  def initialize(actor:, current_session_public_id: nil, request: nil)
    @actor = actor
    @current_session_public_id = current_session_public_id
    @request = request
  end

  def start!
    now = Time.current

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_requested!(now: now)
    end

    notify("requested")
    actor
  end

  def suspend!
    now = Time.current
    deactivated = actor.deactivated_at.presence || now

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_discarded!(now: now)
      actor.update!(
        withdrawal_started_at: actor.withdrawal_started_at.presence || now,
        deactivated_at: deactivated,
        discarded_at: deactivated,
        purged_at: if actor.purged_at.present? && finite_future_time?(actor.purged_at)
                     actor.purged_at
                   else
                     deactivated + RECOVERY_PERIOD
                   end,
      )
      revoke_sessions(except_public_id: current_session_public_id)
    end

    notify(
      "suspended", deactivated_at: actor.deactivated_at, discarded_at: actor.discarded_at,
                   purged_at: actor.purged_at,
    )
    actor
  end

  def recover!
    raise Sign::WithdrawalRecoveryNotAvailableError unless actor.can_recover?

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_recovered!(now: Time.current)
      actor.update!(
        withdrawal_started_at: nil,
        deactivated_at: nil,
        discarded_at: Float::INFINITY,
        purged_at: Float::INFINITY,
        withdrawn_at: nil,
      )
    end

    notify("recovered")
    actor
  end

  def terminate!
    raise Sign::InvalidWithdrawalStateError, actor.class.name unless actor.early_terminatable?

    actor.class.transaction do
      actor.lock!
      ensure_withdrawal_flow_terminated!(now: Time.current)
      if actor.respond_to?(:terminated_at=)
        actor.terminated_at = Time.current
        actor.save!(validate: false)
      end
      WithdrawalPersonalDataAnonymizer.call(actor:)
      revoke_sessions
    end

    notify("terminated", terminated_at: actor.try(:terminated_at))
    actor
  end

  private

  attr_reader :actor, :current_session_public_id, :request

  def ensure_withdrawal_flow_requested!(now:)
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "REQUESTED", now: now)
    return cycle if cycle.withdrawal_requested?
    return cycle if cycle.withdrawal_closing? || cycle.withdrawal_discarded?

    raise Sign::InvalidWithdrawalStateError, withdrawal_flow_class.status_name_for(cycle.status_id)
  end

  def ensure_withdrawal_flow_discarded!(now:)
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "REQUESTED", now: now)
    cycle.confirm_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "confirmed",
      ),
    ) if cycle.withdrawal_requested?
    cycle.discard_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "discarded",
      ),
    ) if cycle.withdrawal_closing?
    cycle
  end

  def ensure_withdrawal_flow_recovered!(now:)
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "DISCARDED", now: now)
    cycle.recover_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "recovered",
      ),
    ) if cycle.withdrawal_discarded?
    cycle
  end

  def ensure_withdrawal_flow_terminated!(now:)
    cycle = active_withdrawal_flow || create_withdrawal_flow!(status: "DISCARDED", now: now)
    cycle.terminate_withdrawal!(
      **withdrawal_flow_event_attrs(
        now: now,
        reason: "terminated",
      ),
    ) if cycle.withdrawal_discarded?
    cycle
  end

  def active_withdrawal_flow
    withdrawal_flow_scope.active.recent_first.first
  end

  def create_withdrawal_flow!(status:, now:)
    withdrawal_flow_class.create!(
      withdrawal_flow_actor_key => actor,
      :status_id => withdrawal_flow_class.status_id_for(status),
      :began_at => actor.withdrawal_started_at.presence || now,
    )
  end

  def withdrawal_flow_scope
    actor.public_send(withdrawal_flow_association)
  end

  def withdrawal_flow_class
    case actor.class.name
    when "Client" then ClientWithdrawalFlow
    when "Visitor" then VisitorWithdrawalFlow
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def withdrawal_flow_association
    case actor.class.name
    when "Client" then :client_withdrawal_flows
    when "Visitor" then :visitor_withdrawal_flows
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def withdrawal_flow_actor_key
    case actor.class.name
    when "Client" then :client
    when "Visitor" then :visitor
    else
      raise Sign::InvalidWithdrawalStateError, actor.class.name
    end
  end

  def withdrawal_flow_event_attrs(now:, reason:)
    {
      now: now,
      token_public_id: current_session_public_id,
      reason: reason,
    }
  end

  def revoke_sessions(except_public_id: nil)
    scope = AuthenticationSessionRevoker.tokens_for(actor)
    scope =
      if except_public_id.present?
        exclude_fresh_withdrawal_step_up_sessions(exclude_session_identifier(scope, except_public_id))
      else
        exclude_fresh_withdrawal_step_up_sessions(scope)
      end
    scope.find_each(&:revoke!)
  end

  def exclude_session_identifier(scope, identifier)
    excluded = scope.where.not(public_id: identifier)
    return excluded unless scope.klass.column_names.include?("oidc_sid") && uuid_identifier?(identifier)

    excluded.where.not(oidc_sid: identifier)
  end

  def exclude_fresh_withdrawal_step_up_sessions(scope)
    return scope unless scope.klass.column_names.include?("last_step_up_at")

    scope.where.not(
      id: scope.where(
        last_step_up_scope: "withdrawal",
        last_step_up_purpose: "step_up",
      ).where(scope.klass.arel_table[:last_step_up_at].gt(VerificationBase::STEP_UP_TTL.ago)).select(:id),
    )
  end

  def uuid_identifier?(value)
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
      value.to_s,
    )
  end

  def finite_future_time?(value)
    return false if value.blank?
    return false if value.respond_to?(:infinite?) && value.infinite?

    value.future?
  end

  def notify(state, payload = {})
    Rails.logger.info(
      JitLogEvent.format(
        "#{actor_event_prefix}.withdrawal.#{state}",
        actor_id_key => actor.id,
        :ip_address => request&.remote_ip,
        **payload,
      ),
    )
  end

  def actor_event_prefix
    actor.is_a?(Visitor) ? "visitor" : "user"
  end

  def actor_id_key
    actor.is_a?(Visitor) ? :visitor_id : :user_id
  end
end
