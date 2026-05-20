# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Verification
      class BaseController < Sign::App::PrivateController
        include ::CloudflareTurnstile
        include Sign::AppVerificationBase

        skip_before_action :enforce_verification_if_required, raise: false

        private

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
            sign_app_configuration_path(ri: params[:ri]),
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
          current_client.client_one_time_passwords
            .where(user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE)
            .order(created_at: :desc)
        end
      end
    end
  end
end
