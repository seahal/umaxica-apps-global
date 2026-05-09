# typed: false
# frozen_string_literal: true

module Sign
  module VerificationReauthLifecycle
    extend ActiveSupport::Concern

    private

    def require_reauth_session!
      return true if valid_reauth_session?(current_reauth_session)
      return true if handle_invalid_reauth_session!

      false
    end

    def consume_reauth_session!
      rs = current_reauth_session
      return_to = rs["return_to"]
      scope = rs["scope"]

      now = Time.current
      verification, raw_token = verification_model.issue_for_token!(token: actor_token)
      actor_token.update!(last_step_up_at: now, last_step_up_scope: scope)
      set_verification_cookie!(raw_token, expires_at: verification.lapses_at)
      create_audit_event!(verification_success_event_id, subject: current_verification_actor)

      clear_reauth_state!

      flash[:notice] = I18n.t(verification_success_notice_key)
      safe_redirect_to(return_to, fallback: verification_success_fallback_path)
    end

    def valid_reauth_session?(_session_data)
      raise NotImplementedError, "#{self.class} must define #valid_reauth_session?"
    end

    def handle_invalid_reauth_session!
      raise NotImplementedError, "#{self.class} must define #handle_invalid_reauth_session!"
    end

    def clear_reauth_state!
      raise NotImplementedError, "#{self.class} must define #clear_reauth_state!"
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
