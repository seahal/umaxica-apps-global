# typed: false
# frozen_string_literal: true

module Sign
  module VerificationStepUpLifecycle
    extend ActiveSupport::Concern

    private

    def require_step_up_session!
      return true if valid_step_up_session?(current_step_up_session)
      return true if handle_invalid_step_up_session!

      false
    end

    def consume_step_up_session!
      rs = current_step_up_session
      return_to = rs.return_to
      scope = rs.scope

      now = Time.current
      ActiveRecord::Base.connected_to(role: :writing) do
        verification, raw_token = verification_model.issue_for_token!(token: actor_token)
        actor_token.update!(last_step_up_at: now, last_step_up_scope: scope)
        Actor.install_context!(
          step_up: StepUp::Resolver.call(token: actor_token, scope: scope, now: now),
        ) if defined?(Actor)
        set_verification_cookie!(raw_token, expires_at: verification.discarded_at)
        create_audit_event!(verification_success_event_id, subject: current_verification_actor)

        clear_step_up_state!
        rs.destroy!
      end

      # Session-fixation defense: rotate the Rails session id at the AAL1->AAL2
      # privilege elevation, mirroring Authentication::Base#log_in. Safe here
      # because the WebAuthn challenge was already consumed by verify_passkey!,
      # return_to/scope are local vars, and the step-up session is DB-backed
      # (rs.destroy!). Must precede the flash assignment since flash is stored
      # in the session and reset_session would otherwise discard it.
      reset_session

      flash[:notice] = I18n.t(verification_success_notice_key)
      safe_redirect_to(return_to, fallback: verification_success_fallback_path)
    end

    def valid_step_up_session?(_session_data)
      raise NotImplementedError, "#{self.class} must define #valid_step_up_session?"
    end

    def handle_invalid_step_up_session!
      raise NotImplementedError, "#{self.class} must define #handle_invalid_step_up_session!"
    end

    def clear_step_up_state!
      raise NotImplementedError, "#{self.class} must define #clear_step_up_state!"
    end

    def record_failed_step_up_attempt!(method)
      step_up_session = current_step_up_session
      if step_up_session.is_a?(Hash)
        step_up_session["attempt_count"] = step_up_session["attempt_count"].to_i + 1
      elsif step_up_session
        step_up_session.with_lock do
          step_up_session.attempt_count = step_up_session.attempt_count.to_i + 1
          step_up_session.save!
        end
      end
      StepUp::CooldownStamp.call(current_verification_actor, method) if current_verification_actor.present?
    end

    def verification_model
      raise NotImplementedError, "#{self.class} must define #verification_model"
    end

    def verification_success_event_id
      raise NotImplementedError, "#{self.class} must define #verification_success_event_id"
    end

    def verification_success_notice_key
      raise NotImplementedError, "#{self.class} must define #verification_success_notice_key"
    end

    def verification_success_fallback_path
      raise NotImplementedError, "#{self.class} must define #verification_success_fallback_path"
    end
  end
end
