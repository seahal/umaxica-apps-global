# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Verification
      class BaseController < Sign::App::ApplicationController
        include ::CloudflareTurnstile

        include SignAppVerificationBase
        include ::PreferenceGlobal
        include CommonOtp
        include ::VerificationClient
        include SignWebauthn
        include SignVerificationTiming
        include SignVerificationCommonBase
        include SignVerificationAuditAndCookie
        include SignVerificationStepUpSessionStore
        include SignVerificationStepUpLifecycle
        include SignVerificationPasskeyChecks
        include SignVerificationTotpChecks

        AUTHENTICATION_MODE = :private

        before_action :apply_localization_preferences
        before_action :authenticate_client!
        before_action :set_actor_token
        before_action :require_ri!
        before_action :enforce_step_up_prereqs!
        skip_before_action :enforce_verification_if_required
        before_action :authorize_verification_actor!

        private

        def authorize_verification_actor!
          authorize!(current_verification_actor, to: :show?)
        end

        def valid_step_up_session?(rs)
          rs.present? &&
            rs.discarded_at > Time.current &&
            rs.user_token_id == actor_token.id &&
            rs.status == "PENDING" &&
            rs.scope.present? &&
            rs.return_to.present?
        end

        def handle_invalid_step_up_session!
          clear_step_up_state!
          destroy_current_step_up_session!

          if restore_step_up_session_from_params! && valid_step_up_session?(current_step_up_session)
            return true
          end

          safe_redirect_to(
            sign_app_settings_path(ri: params[:ri]),
            fallback: sign_app_root_path(ri: params[:ri]),
            alert: I18n.t("auth.step_up.session_expired"),
          )
          false
        end

        def verification_unavailable_redirect_path
          sign_app_verification_path(ri: params[:ri])
        end

        def clear_step_up_state!
          Rails.cache.delete(email_otp_cache_key) if current_step_up_session.present?
        end

        def verification_model
          ClientVerification
        end

        def verification_success_event_id
          ClientChronicleEvent::STEP_UP_VERIFIED
        end

        def verification_success_notice_key
          "sign.app.verification.success.complete"
        end

        def verification_success_fallback_path
          sign_app_verification_path(ri: params[:ri])
        end

        def verification_audit_event_class = ClientChronicleEvent

        def verification_audit_level_class = ClientChronicleLevel

        def verification_default_activity_level_id = ClientChronicleLevel::NOTHING

        def verification_activity_model = ClientChronicle

        def current_verification_actor = current_client

        def verification_actor_type = "Client"

        def verification_passkeys_scope
          current_client.client_passkeys
        end

        def verification_passkey_model
          ClientPasskey
        end

        def passkey_actor_matches?(passkey)
          passkey.user_id == current_client.id
        end

        def verification_no_passkey_i18n_key
          "sign.app.verification.errors.no_passkey"
        end

        def active_totp_credentials
          current_client.client_totp_credentials
            .where(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
            .order(created_at: :desc)
        end
      end
    end
  end
end
