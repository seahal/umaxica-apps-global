# typed: false
# frozen_string_literal: true

class AuthenticationLogoutCurrentSession
  def self.call(...)
    new(...).call
  end

  def initialize(current: nil, resource: nil, token: nil, token_class: nil, session_public_id: nil,
                 reason: "user_logout", cascade_device_session_tokens: true)
    @current = current
    @resource = resource
    @token = token
    @token_class = token_class
    @session_public_id = session_public_id.presence || current_session_from_current
    @reason = reason
    @cascade_device_session_tokens = cascade_device_session_tokens
  end

  def call
    token_record = resolved_token
    return true if recent_completed_sign_out_flow?(token_record)

    cycle = begin_sign_out_flow(token_record)
    begin
      cycle&.mark_access_discarded!
      revoke_device_session!(token_record)
      revoke_token!(token_record) unless device_session_cascade_handles_token?(token_record)
      cycle&.mark_logically_revoked!
      cycle&.await_sign_out_expiry!
      cycle&.complete_sign_out!
    rescue StandardError
      fail_sign_out_flow(cycle)
      raise
    end
    true
  end

  private

  attr_reader :current, :resource, :token, :token_class, :session_public_id, :reason,
              :cascade_device_session_tokens

  def current_session_from_current
    return unless current.respond_to?(:session)

    current.session
  end

  def resolved_token
    return token if token.present?
    return if token_class.blank? || session_public_id.blank?

    device_session = token_column?(:device_session_id) ? find_device_session : nil
    if device_session
      return token_class.currently_usable_at
          .where(device_session_id: device_session.id)
          .order(created_at: :desc)
          .first
    end

    find_token_by(:public_id) || find_token_by(:oidc_sid)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotDefined
    nil
  end

  def find_token_by(column)
    return unless token_column?(column)
    return if column == :oidc_sid && !uuid_identifier?(session_public_id)

    token_class.find_by(column => session_public_id)
  end

  def token_column?(column)
    return false unless token_class.respond_to?(:column_names)

    token_class.column_names.include?(column.to_s)
  end

  def uuid_identifier?(value)
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
      value.to_s,
    )
  end

  def find_device_session
    klass = device_session_class
    return unless klass

    klass.active.find_by(public_id: session_public_id)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotDefined
    nil
  end

  def device_session_class
    return token.device_session.class if token&.respond_to?(:device_session) && token.device_session.present?

    case token_class&.name
    when "ClientToken" then ClientDeviceSession
    when "OperatorToken" then OperatorDeviceSession
    when "VisitorToken" then VisitorDeviceSession
    end
  end

  def revoke_device_session!(token_record)
    return true if token_record.respond_to?(:revoked?) && token_record.revoked?

    device_session = token_record&.respond_to?(:device_session) ? token_record.device_session : find_device_session
    return if device_session.blank?

    device_session.revoke!(reason: reason)
    return unless cascade_device_session_tokens

    if token_record&.class&.respond_to?(:where)
      token_record.class.where(device_session_id: device_session.id).find_each { |session_token|
        revoke_token!(session_token)
      }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ActiveRecord::StatementInvalid,
         ActiveRecord::ConnectionNotDefined => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_current_session.device_session_failed",
        reason: reason,
        resource_class: resource&.class&.name,
        resource_id: resource&.id,
        token_class: token_record&.class&.name,
        token_id: token_record&.try(:public_id),
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    true
  end

  def revoke_token!(token_record)
    return true if token_record.blank?
    return true if token_record.respond_to?(:revoked?) && token_record.revoked?

    if token_record.respond_to?(:revoke!)
      token_record.revoke!
    elsif token_record.respond_to?(:destroy)
      token_record.destroy
    end
    true
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordInvalid => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_current_session.failed",
        reason: reason,
        resource_class: resource&.class&.name,
        resource_id: resource&.id,
        token_class: token_record&.class&.name,
        token_id: token_record&.try(:public_id),
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    true
  end

  def device_session_cascade_handles_token?(token_record)
    cascade_device_session_tokens &&
      token_record&.respond_to?(:device_session) &&
      token_record.device_session.present?
  end

  def begin_sign_out_flow(token_record)
    cycle_class = sign_out_flow_class_for(token_record)
    return if cycle_class.blank?

    cycle_class.connection_class_for_self.connected_to(role: :writing) do
      cycle_class.create!(
        principal_id: sign_out_principal_id(token_record),
        token: token_record,
        kind_id: cycle_class.kind_id_for("IDP_SIGN_OUT"),
        refresh_token_family_id: sign_out_refresh_token_family_id(token_record),
        requested_at: Time.current,
        access_expires_at: Time.current,
        refresh_expires_at: sign_out_refresh_expires_at(token_record),
      )
    end
  rescue ActiveRecord::ActiveRecordError, ArgumentError => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_current_session.cycle_unavailable",
        reason: reason,
        resource_class: resource&.class&.name,
        resource_id: resource&.id,
        token_class: token_record&.class&.name,
        token_id: token_record&.try(:public_id),
        error_class: e.class.name,
      ),
    )
    nil
  end

  def recent_completed_sign_out_flow?(token_record)
    return false unless token_record&.respond_to?(:revoked?) && token_record.revoked?

    cycle_class = sign_out_flow_class_for(token_record)
    return false if cycle_class.blank?

    cycle_class.where(token_id: token_record.id)
      .where(status_id: cycle_class.status_id_for("COMPLETED"))
      .where(cycle_class.arel_table[:completed_at].gt(5.minutes.ago))
      .exists?
  rescue ActiveRecord::ActiveRecordError, ArgumentError
    false
  end

  def fail_sign_out_flow(cycle)
    return if cycle.blank? || cycle.sign_out_completed? || cycle.sign_out_failed?

    cycle.class.connection_class_for_self.connected_to(role: :writing) do
      cycle.reload.fail_sign_out!
    end
  rescue ActiveRecord::ActiveRecordError, FlowInvalidTransition
    nil
  end

  def sign_out_flow_class_for(token_record)
    case token_record
    when ClientToken then ClientSignOutFlow
    when VisitorToken then VisitorSignOutFlow
    when OperatorToken then OperatorSignOutFlow
    end
  end

  def sign_out_principal_id(token_record)
    return token_record.user_id if token_record.respond_to?(:user_id)
    return token_record.visitor_id if token_record.respond_to?(:visitor_id)
    return token_record.staff_id if token_record.respond_to?(:staff_id)

    resource&.id
  end

  def sign_out_refresh_token_family_id(token_record)
    token_record.refresh_token_family_id if token_record.respond_to?(:refresh_token_family_id)
  end

  def sign_out_refresh_expires_at(token_record)
    discarded_at = token_record.discarded_at if token_record.respond_to?(:discarded_at)
    return 100.years.from_now if discarded_at.respond_to?(:infinite?) && discarded_at.infinite?
    return discarded_at if discarded_at.present? && discarded_at > Time.current

    Time.current
  end
end
