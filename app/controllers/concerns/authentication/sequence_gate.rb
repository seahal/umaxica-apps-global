# typed: false
# frozen_string_literal: true

module Authentication
  module SequenceGate
    extend ActiveSupport::Concern

    def sign_in_sequence_redirect_path(rt: nil, default_path: after_dashboard_path)
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        url_rt = safe_encoded_rt(rt)
        return sign_in_checkpoint_path(rt: url_rt) if issue_checkpoint!

        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_checkpoint_participant(cycle).advance_if_clear!
          end
        return sign_in_checkpoint_path(rt: url_rt) if result.blocking?

        return issue_welcome_gate_and_path(rt: url_rt, sequence_id: cycle.public_id)
      end

      checkpoint_required = issue_checkpoint!
      sequence = begin_sign_in_sequence!(rt: rt, checkpoint_required: checkpoint_required)

      if checkpoint_required
        sign_in_checkpoint_path(rt: rt)
      else
        after_checkpoint_sequence_path(rt: rt, default_path: default_path, sequence_id: sequence&.sequence_id)
      end
    end

    def redirect_to_sign_in_sequence!(rt: nil, default_path: after_dashboard_path, **redirect_options)
      redirect_to(sign_in_sequence_redirect_path(rt: rt, default_path: default_path), **redirect_options)
    end

    def after_checkpoint_sequence_path(rt: nil, default_path: after_dashboard_path, sequence_id: nil)
      return issue_welcome_gate_and_path(rt: rt, sequence_id: sequence_id) if dashboard_sequence_step_required?

      safe_path_from_encoded_rt(rt, fallback: default_path)
    end

    def redirect_after_checkpoint_sequence!(rt: nil, default_path: after_dashboard_path, **redirect_options)
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        return reject_invalid_sign_in_sequence! unless cycle.sign_in_checkpoint_pending?
        return reject_invalid_sign_in_sequence! unless allowed_to?(:complete_checkpoint?, cycle)

        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_checkpoint_participant(cycle).advance_if_clear!
          end
        if result.blocking?
          return redirect_to(sign_in_checkpoint_path(rt: cycle.reload.return_to.presence || rt), **redirect_options)
        end

        return redirect_to(
          issue_welcome_gate_and_path(rt: cycle.reload.return_to.presence || rt, sequence_id: cycle.public_id),
          **redirect_options,
        )
      end

      sign_in_sequence_carrier.advance!(state: "DASHBOARD_PENDING", participant: "dashboard")
      redirect_to(after_checkpoint_sequence_path(rt: rt, default_path: default_path), **redirect_options)
    end

    def continue_checkpoint_sequence_without_content!
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        return reject_invalid_sign_in_sequence! unless cycle.sign_in_checkpoint_pending?
        return reject_invalid_sign_in_sequence! unless allowed_to?(:show_checkpoint?, cycle)
        return if bulletin_state.present?

        result =
          with_sign_in_cycle_writing(cycle) do
            sign_in_checkpoint_participant(cycle).advance_if_clear!
          end
        return if result.blocking?

        redirect_to(issue_welcome_gate_and_path(rt: cycle.reload.return_to, sequence_id: cycle.public_id))
        return
      end

      if sign_in_sequence_required_for_participant?(:checkpoint)
        return unless require_sign_in_sequence_participant!(
          participant: :checkpoint,
          policy_rule: :show_checkpoint?,
        )
      end

      return if bulletin_state.present?

      redirect_after_checkpoint_sequence!(rt: redirect_parameter_value)
    end

    def continue_welcome_sequence_without_content!
      cycle = current_db_sign_in_cycle_for_sequence
      if cycle
        if cycle.sign_in_completed?
          clear_welcome_gate!
          clear_current_sign_in_cycle_locator!
          return redirect_to(after_welcome_path)
        end
        return redirect_to(sign_in_checkpoint_path(rt: cycle.return_to)) if cycle.sign_in_checkpoint_pending?
        return reject_invalid_sign_in_sequence! unless cycle.sign_in_dashboard_pending?
        return reject_invalid_sign_in_sequence! unless allowed_to?(:show_dashboard?, cycle)
        return redirect_to(after_welcome_path) unless welcome_gate_available?(sequence_id: cycle.public_id)
        return redirect_to(after_welcome_path) unless consume_welcome_gate!(sequence_id: cycle.public_id)

        with_sign_in_cycle_writing(cycle) do
          sign_in_dashboard_participant(cycle).advance!
        end
        cycle = with_sign_in_cycle_writing(cycle) { cycle.reload }
        return reject_invalid_sign_in_sequence! unless allowed_to?(:consume_return?, cycle)

        destination =
          with_sign_in_cycle_writing(cycle) do
            SignIn::ReturnParticipant.new(
              cycle: cycle,
              default_path: after_welcome_path,
            ).consume!
          end
        clear_welcome_gate!
        clear_current_sign_in_cycle_locator!
        fallback_destination = safe_non_welcome_return_path(after_welcome_path, fallback: nil)
        destination = safe_non_welcome_return_path(destination, fallback: fallback_destination)
        @welcome_next_path = destination if destination.present?
        return
      end

      return redirect_to(after_welcome_path) unless welcome_gate_available?
      sign_in_sequence_carrier.complete! if sign_in_sequence_carrier.current.participant == "dashboard"
      return redirect_to(after_welcome_path) unless consume_welcome_gate!

      destination = safe_path_from_encoded_rt(redirect_parameter_value, fallback: after_welcome_path)
      clear_welcome_gate!
      sign_in_sequence_carrier.clear!
      @welcome_next_path = destination
    end

    alias continue_dashboard_sequence_without_content! continue_welcome_sequence_without_content!

    def dashboard_sequence_step_required?
      true
    end

    def sign_in_sequence_required_for_participant?(_participant)
      true
    end

    def sign_in_sequence_carrier
      @sign_in_sequence_carrier ||= SignIn::SequenceCarrier.new(session, surface: sign_in_sequence_surface)
    end

    def sign_in_sequence_surface
      Actor.tld
    end

    def welcome_gate_key
      {
        "app" => :app_sign_in_welcome,
        "com" => :com_sign_in_welcome,
        "org" => :org_sign_in_welcome,
      }[sign_in_sequence_surface.to_s] || :sign_in_welcome
    end

    def issue_welcome_gate_and_path(rt:, sequence_id: nil)
      clear_welcome_gate!
      session[welcome_gate_key] = {
        "remaining" => 5,
        "issued_at" => Time.current.to_i,
        "expires_at" => 10.minutes.from_now.to_i,
        "sequence_id" => sequence_id.presence,
      }
      sign_in_welcome_path(rt: rt)
    end

    def clear_welcome_gate!
      session.delete(welcome_gate_key)
    end

    def consume_welcome_gate!(sequence_id: nil)
      gate = session[welcome_gate_key]
      return false unless gate.is_a?(Hash)
      return clear_welcome_gate! && false if welcome_gate_expired?(gate)
      return clear_welcome_gate! && false if gate["remaining"].to_i <= 0
      if sequence_id.present? && gate["sequence_id"].present? && gate["sequence_id"].to_s != sequence_id.to_s
        return clear_welcome_gate! && false
      end

      remaining = gate["remaining"].to_i - 1
      if remaining <= 0
        clear_welcome_gate!
      else
        session[welcome_gate_key] = gate.merge("remaining" => remaining)
      end
      true
    end

    def welcome_gate_available?(sequence_id: nil)
      gate = session[welcome_gate_key]
      return false unless gate.is_a?(Hash)
      return clear_welcome_gate! && false if welcome_gate_expired?(gate)
      return clear_welcome_gate! && false if gate["remaining"].to_i <= 0
      if sequence_id.present? && gate["sequence_id"].present? && gate["sequence_id"].to_s != sequence_id.to_s
        return clear_welcome_gate! && false
      end

      true
    end

    def welcome_gate_expired?(gate)
      expires_at = gate["expires_at"].to_i
      expires_at <= 0 || Time.current.to_i >= expires_at
    end

    def begin_sign_in_sequence!(rt:, checkpoint_required:)
      actor = current_resource
      return unless actor

      transition = SignIn::StateMachine.after_session_issued(checkpoint_required: checkpoint_required)
      sequence = sign_in_sequence_carrier.start!(
        surface: Actor.tld,
        actor: actor,
        method: Array(Actor.authentication.amr).first || "unknown",
        state: transition.fetch(:state),
        participant: transition.fetch(:participant),
        rt: safe_encoded_rt(rt),
      )

      SignIn::Result.new(
        status: :success,
        actor: actor,
        token: nil,
        sequence_id: sequence.id,
        redirect_to: nil,
        response_status: :found,
        message: nil,
      )
    end

    def require_sign_in_sequence_participant!(participant:, policy_rule:)
      sequence = sign_in_sequence_carrier.current

      allowed = allowed_to?(policy_rule, sequence, with: SignIn::SequencePolicy)
      return true if allowed

      sign_in_sequence_carrier.expire! if sequence.present? && sequence.expired?
      sign_in_sequence_carrier.fail! if sequence.present? && !sequence.expired?

      Rails.logger.info(LogEvent.format(
        "authentication.sign_in_sequence.rejected",
        surface: Actor.tld,
        participant: participant.to_s,
        state: sequence&.state,
        expired: sequence&.expired?,
        actor_type: sequence&.actor_type,
      ))
      render plain: I18n.t("errors.messages.not_authorized"), status: :bad_request
      false
    end

    def current_db_sign_in_cycle_for_sequence
      @current_db_sign_in_cycle_for_sequence ||=
        begin
          token = respond_to?(:current_session, true) ? current_session : nil
          SignIn::CycleLocator.new(
            session,
            surface: sign_in_sequence_surface,
            actor: current_resource,
            token: token,
          ).current
        end
    rescue ArgumentError
      nil
    end

    def with_sign_in_cycle_writing(cycle, &)
      cycle.class.connection_class_for_self.connected_to(role: :writing, &)
    end

    def sign_in_checkpoint_participant(cycle)
      SignIn::CheckpointParticipant.new(cycle: cycle, actor: current_resource)
    end

    def sign_in_dashboard_participant(cycle)
      SignIn::DashboardParticipant.new(cycle: cycle, actor: current_resource)
    end

    def clear_current_sign_in_cycle_locator!
      sign_in_cycle_locator_for(actor: current_resource, token: current_session).clear!
    rescue ArgumentError
      nil
    end

    def reject_invalid_sign_in_sequence!
      render plain: I18n.t("errors.messages.not_authorized"), status: :bad_request
      false
    end

    private

    def start_sign_in_cycle_for!(resource, rt:)
      cycle_class = sign_in_cycle_class_for(resource)
      nonce = SecureRandom.urlsafe_base64(SignIn::CycleLocator::NONCE_BYTES)
      cycle_class.create!(
        principal_id: resource.id,
        status_id: cycle_class.status_id_for("PRIMARY_PENDING"),
        step: "primary",
        return_to: safe_path_from_encoded_rt(rt, fallback: nil),
        nonce_digest: cycle_class.digest_nonce(nonce),
      )
    end

    def complete_sign_in_cycle_after_session_result!(cycle, resource, result)
      return result unless cycle&.persisted?

      if result[:status] == :session_limit_hard_reject
        cycle.advance_sign_in_to_guardrail! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
        sign_in_cycle_locator_for(actor: resource).issue!(cycle)
        return result
      end

      token = current_session
      return result unless token

      if result[:restricted] || result[:session_management_required]
        cycle.advance_sign_in_to_session_limit! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?
        cycle.update!(token: token)
        sign_in_cycle_locator_for(actor: resource, token: token).issue!(cycle)
        reset_current_db_sign_in_cycle_for_sequence!
        return result
      end

      advance_cycle_to_checkpoint_after_active_session!(cycle, resource, token)
      result
    end

    def advance_cycle_to_checkpoint_after_active_session!(cycle, resource, token)
      cycle.advance_sign_in_to_guardrail! if cycle.sign_in_primary_pending? || cycle.sign_in_mfa_pending?

      if cycle.sign_in_guardrail_pending?
        guardrail = SignIn::GuardrailParticipant.new(cycle: cycle, actor: resource)
        guardrail.advance_if_clear!
      end

      cycle.reload
      cycle.update!(token: token) if cycle.token_id.blank?
      cycle.advance_sign_in_to_checkpoint! if cycle.sign_in_session_issuance_pending?
      sign_in_cycle_locator_for(actor: resource, token: token).issue!(cycle.reload)
      reset_current_db_sign_in_cycle_for_sequence!
    end

    def promote_current_session_limit_cycle!(actor)
      cycle = current_db_sign_in_cycle_for_sequence
      return false unless cycle&.sign_in_session_limit_pending?
      return false unless current_session&.restricted?

      result = SignIn::SessionLimitManager.new(
        cycle: cycle,
        actor: actor,
        token: current_session,
      ).promote!
      @current_session = result.token
      @current_session_public_id = result.token.public_id
      advance_cycle_to_checkpoint_after_active_session!(cycle.reload, actor, result.token)
      true
    end

    def pending_mfa_sign_in_cycle_for(resource)
      sign_in_cycle_locator_for(actor: resource).current
    end

    def sign_in_cycle_locator_for(actor: nil, token: nil)
      SignIn::CycleLocator.new(
        session,
        surface: sign_in_sequence_surface_for_actor(actor),
        actor: actor,
        token: token,
      )
    end

    def sign_in_sequence_surface_for_actor(actor)
      case actor
      when ::Client then :app
      when ::Visitor then :com
      when ::Operator then :org
      else sign_in_sequence_surface
      end
    end

    def sign_in_cycle_class_for(resource)
      case resource
      when ::Client then ClientSignInCycle
      when ::Visitor then VisitorSignInCycle
      when ::Operator then OperatorSignInCycle
      else
        raise ArgumentError, "unsupported sign-in cycle actor"
      end
    end

    def reset_current_db_sign_in_cycle_for_sequence!
      return unless defined?(@current_db_sign_in_cycle_for_sequence)

      remove_instance_variable(:@current_db_sign_in_cycle_for_sequence)
    end

    def establish_sign_in_result!(resource, rt:, ri:, auth_method:, token_kind_id: "BROWSER_WEB",
                                  record_login_audit: true, audit_context: {})
      result = establish_signed_in_session!(
        resource,
        rt: rt,
        ri: ri,
        auth_method: auth_method,
        token_kind_id: token_kind_id,
        record_login_audit: record_login_audit,
        audit_context: audit_context,
      )
      sign_in_result_from_session_result(result, actor: resource)
    end

    def sign_in_result_from_session_result(result, actor: nil, sequence_id: nil)
      SignIn::Result.from_session_result(
        result,
        actor: actor,
        sequence_id: sequence_id,
        session_management_path: session_management_path,
      )
    end
  end
end
