# typed: false
# frozen_string_literal: true

module Sign
  module ComVerificationBase
    extend ActiveSupport::Concern

    module Overrides
      private

      def reauth_actor_id
        current_customer.id
      end

      def start_reauth_session!(scope:, return_to_param:)
        decoded = Base64.urlsafe_decode64(return_to_param.to_s)
        safe_path = safe_internal_path(decoded)
        raise ActionController::BadRequest, "invalid return_to" if safe_path.blank?

        scope_str = scope.to_s
        raise ActionController::BadRequest, "invalid scope" unless self.class::ALLOWED_SCOPES.key?(scope_str)

        pattern = self.class::ALLOWED_SCOPES[scope_str]
        raise ActionController::BadRequest, "scope mismatch" unless safe_path.match?(pattern)

        session[self.class::REAUTH_SESSION_KEY] = {
          "customer_id" => reauth_actor_id,
          "scope" => scope_str,
          "return_to" => safe_path,
          "expires_at" => self.class::REAUTH_TTL.from_now.to_i,
        }
      rescue ArgumentError
        raise ActionController::BadRequest, "invalid return_to encoding"
      end

      def valid_reauth_session?(rs)
        rs.present? &&
          rs["expires_at"].to_i > Time.current.to_i &&
          rs["customer_id"] == current_customer.id &&
          rs["scope"].present? &&
          rs["return_to"].present?
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

      def clear_reauth_state!
        session.delete(self.class::REAUTH_SESSION_KEY)
        session.delete(self.class::EMAIL_OTP_SESSION_KEY)
      end

      def verification_model
        CustomerVerification
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

      def current_verification_actor = current_customer

      def verification_actor_type = "Customer"

      def verification_token_foreign_key
        :customer_token_id
      end

      def verification_passkeys_scope
        current_customer.customer_passkeys
      end

      def verification_passkey_model
        CustomerPasskey
      end

      def passkey_actor_matches?(passkey)
        passkey.customer_id == current_customer.id
      end

      def verification_no_passkey_i18n_key
        "sign.app.verification.errors.no_passkey"
      end

      def active_totp_credentials
        []
      end

      def step_up_supported_methods
        %i(email_otp passkey)
      end

      def send_email_otp!
        customer_email =
          current_customer.customer_emails.where(
            customer_email_status_id: CustomerEmailStatus::VERIFIED,
          ).order(created_at: :desc).first
        unless customer_email
          @verification_errors = ["メールアドレスが未確認です"]
          return false
        end

        secret, counter, pass_code = generate_hotp_code
        rs = current_reauth_session
        session[self.class::EMAIL_OTP_SESSION_KEY] = {
          "secret" => secret,
          "counter" => counter,
          "expires_at" => rs["expires_at"],
        }

        Email::App::RegistrationMailer.with(
          hotp_token: pass_code,
          email_address: customer_email.address,
          public_id: current_customer.public_id,
          verification_token: nil,
        ).create.deliver_later

        true
      end
    end

    included do
      auth_required!
      include Sign::AppVerificationBase
      prepend Overrides
    end
  end
end
