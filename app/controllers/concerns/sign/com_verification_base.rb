# typed: false
# frozen_string_literal: true

module Sign
  module ComVerificationBase
    extend ActiveSupport::Concern

    module Overrides
      private

      def reauth_session_model = VisitorReauthSession

      def reauth_session_token_foreign_key = :visitor_token_id

      def valid_reauth_session?(rs)
        rs.present? &&
          rs.lapses_at > Time.current &&
          rs.visitor_token_id == actor_token.id &&
          rs.status == "PENDING" &&
          rs.scope.present? &&
          rs.return_to.present?
      end

      def handle_invalid_reauth_session!
        clear_reauth_state!
        if restore_reauth_session_from_params! && valid_reauth_session?(current_reauth_session)
          return true
        end

        safe_redirect_to(
          sign_com_verification_path(verification_recovery_redirect_params),
          fallback: sign_com_verification_path(ri: params[:ri]),
          alert: I18n.t("auth.step_up.session_expired"),
        )
        false
      end

      def verification_unavailable_redirect_path
        sign_com_verification_path(ri: params[:ri])
      end

      def verification_recovery_redirect_params
        attrs = { ri: params[:ri] }

        scope = optional_incoming_scope || current_reauth_scope
        attrs[:scope] = scope if scope.present?

        return_to = optional_incoming_return_to || current_reauth_return_to_param
        attrs[:return_to] = return_to if return_to.present?

        attrs
      end

      def optional_incoming_scope
        verification_params[:scope].to_s.presence || params.expect(:scope).to_s.presence
      end

      def optional_incoming_return_to
        verification_params[:return_to].to_s.presence ||
          verification_params[:rt].to_s.presence ||
          params.expect(:return_to).to_s.presence ||
          params.expect(:rt).to_s.presence
      end

      def clear_reauth_state!
        Rails.cache.delete(email_otp_cache_key) if current_reauth_session.present?
      end

      def verification_model
        VisitorVerification
      end

      def verification_success_event_id
        UserChronicleEvent::STEP_UP_VERIFIED
      end

      def verification_success_notice_key
        "sign.app.verification.success.complete"
      end

      def verification_success_fallback_path
        sign_com_verification_path(ri: params[:ri])
      end

      def verification_audit_event_class = UserChronicleEvent

      def verification_audit_level_class = UserChronicleLevel

      def verification_default_activity_level_id = UserChronicleLevel::NOTHING

      def verification_activity_model = UserChronicle

      def current_verification_actor = current_visitor

      def verification_actor_type = "Visitor"

      def verification_token_foreign_key
        :visitor_token_id
      end

      def verification_passkeys_scope
        current_visitor.visitor_passkeys
      end

      def verification_passkey_model
        VisitorPasskey
      end

      def passkey_actor_matches?(passkey)
        passkey.visitor_id == current_visitor.id
      end

      def verification_no_passkey_i18n_key
        "sign.app.verification.errors.no_passkey"
      end

      def step_up_supported_methods
        %i(email_otp passkey)
      end

      def send_email_otp!
        visitor_email =
          current_visitor.visitor_emails.where(
            visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES,
          ).order(created_at: :desc).first
        unless visitor_email
          @verification_errors = ["メールアドレスが未確認です"]
          return false
        end

        secret, counter, pass_code = generate_hotp_code
        Rails.cache.write(
          email_otp_cache_key, {
            "secret" => secret,
            "counter" => counter,
          }, expires_in: [current_reauth_session.lapses_at - Time.current, 0].max,
        )

        enqueue_step_up_email_otp!(
          hotp_token: pass_code,
          email_address: visitor_email.address,
          public_id: current_visitor.public_id,
        )

        true
      end

      def enqueue_step_up_email_otp!(hotp_token:, email_address:, public_id:)
        SolidQueue::Record.connected_to(role: :writing) do
          Email::App::RegistrationMailer.with(
            hotp_token: hotp_token,
            email_address: email_address,
            public_id: public_id,
            verification_token: nil,
          ).create.deliver_later
        end
      end
    end

    included do
      auth_required!
      include Sign::AppVerificationBase
      prepend Overrides
    end
  end
end
