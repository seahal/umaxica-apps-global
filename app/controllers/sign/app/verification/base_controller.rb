# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Verification
      class BaseController < Sign::App::ApplicationController
        auth_required!

        include Sign::AppVerificationBase

        private

        def reauth_actor_id
          current_user.id
        end

        def valid_reauth_session?(rs)
          rs.present? &&
            rs["expires_at"].to_i > Time.current.to_i &&
            rs["user_id"] == current_user.id &&
            rs["scope"].present? &&
            rs["return_to"].present?
        end

        def handle_invalid_reauth_session!
          clear_reauth_state!
          if restore_reauth_session_from_params! && valid_reauth_session?(current_reauth_session)
            return true
          end

          safe_redirect_to(
            sign_app_verification_path(verification_recovery_redirect_params),
            fallback: sign_app_verification_path(ri: params[:ri]),
            alert: I18n.t("auth.step_up.session_expired"),
          )
          false
        end

        def verification_unavailable_redirect_path
          sign_app_verification_path(ri: params[:ri])
        end

        def clear_reauth_state!
          session.delete(self.class::REAUTH_SESSION_KEY)
          session.delete(self.class::EMAIL_OTP_SESSION_KEY)
        end

        def verification_model
          UserVerification
        end

        def verification_success_event_id
          UserChronicleEvent::STEP_UP_VERIFIED
        end

        def verification_success_notice_key
          "sign.app.verification.success.complete"
        end

        def verification_success_fallback_path
          sign_app_verification_path(ri: params[:ri])
        end

        def verification_audit_event_class = UserChronicleEvent

        def verification_audit_level_class = UserChronicleLevel

        def verification_default_activity_level_id = UserChronicleLevel::NOTHING

        def verification_activity_model = UserChronicle

        def current_verification_actor = current_user

        def verification_actor_type = "User"

        def verification_passkeys_scope
          current_user.user_passkeys
        end

        def verification_passkey_model
          UserPasskey
        end

        def passkey_actor_matches?(passkey)
          passkey.user_id == current_user.id
        end

        def verification_no_passkey_i18n_key
          "sign.app.verification.errors.no_passkey"
        end

        def active_totp_credentials
          current_user.user_one_time_passwords
            .where(user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE)
            .order(created_at: :desc)
        end
      end
    end
  end
end
