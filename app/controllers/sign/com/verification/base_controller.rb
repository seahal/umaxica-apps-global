# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Verification
      class BaseController < ::Sign::Com::ApplicationController
        include SignComVerificationBase
        include ::PreferenceGlobal
        include CommonOtp
        include ::AuthenticationVisitor
        include ::VerificationVisitor
        include SignWebauthn
        include SignVerificationTiming
        include SignVerificationCommonBase
        include SignVerificationAuditAndCookie
        include SignVerificationStepUpSessionStore
        include SignVerificationStepUpLifecycle
        include SignVerificationPasskeyChecks
        include SignEmailOtpVerificationSupport
        prepend SignComVerificationBase::Overrides

        AUTHENTICATION_MODE = :private

        before_action :apply_localization_preferences
        before_action :authenticate_visitor!
        before_action :set_actor_token
        before_action :require_ri!
        before_action :enforce_step_up_prereqs!
        skip_before_action :enforce_verification_if_required
        before_action :authorize_verification_actor!

        private

        def authorize_verification_actor!
          authorize!(current_verification_actor, to: :show?)
        end

        def step_up_session_model = VisitorStepUpSession

        def step_up_session_token_foreign_key = :visitor_token_id

        def valid_step_up_session?(rs)
          rs.present? &&
            rs.discarded_at > Time.current &&
            rs.visitor_token_id == actor_token.id &&
            rs.status == "PENDING" &&
            rs.scope.present? &&
            rs.return_to.present?
        end

        def handle_invalid_step_up_session!
          clear_step_up_state!
          if restore_step_up_session_from_params! && valid_step_up_session?(current_step_up_session)
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

        def clear_step_up_state!
          Rails.cache.delete(email_otp_cache_key) if current_step_up_session.present?
        end

        def verification_model
          VisitorVerification
        end

        def verification_success_event_id
          ClientChronicleEvent::STEP_UP_VERIFIED
        end

        def verification_success_notice_key
          "sign.app.verification.success.complete"
        end

        def verification_success_fallback_path
          sign_com_verification_path(ri: params[:ri])
        end

        def verification_audit_event_class = ClientChronicleEvent

        def verification_audit_level_class = ClientChronicleLevel

        def verification_default_activity_level_id = ClientChronicleLevel::NOTHING

        def verification_activity_model = ClientChronicle

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
              visitor_email_status_id: VisitorEmailStatus::VERIFIED,
            ).order(created_at: :desc).first
          unless visitor_email
            @verification_errors = [I18n.t("sign.app.verification.errors.email_not_verified")]
            return false
          end

          secret_credential, counter, pass_code = generate_hotp_code
          Rails.cache.write(
            email_otp_cache_key, {
              "secret_credential" => secret_credential,
              "counter" => counter,
            }, expires_in: [current_step_up_session.discarded_at - Time.current, 0].max,
          )

          Email::Com::OtpMailer.with(
            encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp(pass_code),
            email_address: visitor_email.address,
            public_id: current_visitor.public_id,
            verification_token: nil,
          ).create.deliver_later

          true
        end
      end
    end
  end
end
