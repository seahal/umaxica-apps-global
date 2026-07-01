# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Verification
      class BaseController < ::Auth::Com::ApplicationController
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
        helper_method :current_step_up_scope, :current_step_up_pt_param

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
            auth_com_verification_path(verification_recovery_redirect_params),
            fallback: auth_com_verification_path(ri: params[:ri]),
            alert: I18n.t("auth.step_up.session_expired"),
          )
          false
        end

        def verification_unavailable_redirect_path
          auth_com_verification_path(ri: params[:ri])
        end

        def clear_step_up_state!
          session.delete(email_otp_session_key) if step_up_session_storage_available?
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
          auth_com_verification_path(ri: params[:ri])
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

          _secret_credential, _counter, pass_code = generate_hotp_code
          write_email_otp_session_data!(
            (current_email_otp_session_data || {}).merge(
              "otp_digest" => email_otp_digest(pass_code),
            ),
          )

          OtpAdapter.for(surface: :com, channel: :email).deliver(
            record: visitor_email,
            otp_code: pass_code,
            public_id: current_visitor.public_id,
            verification_token: nil,
          )

          true
        end
      end
    end
  end
end
