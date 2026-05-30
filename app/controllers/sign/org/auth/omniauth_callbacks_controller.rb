# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Auth
      # Controller for handling Google OAuth callbacks for operators sign-in.
      #
      # Routes:
      #   GET /auth/google_org/callback -> #omniauth
      #   GET /auth/failure            -> #failure
      #
      # Operator continue signs in existing staff only:
      # - Extracts email from Google auth hash
      # - Looks up Operator via OperatorEmail by that email
      # - Signs in the operator if found and active
      class OmniauthCallbacksController < Sign::Org::ApplicationController
        include SocialAuthConcern

        include SocialCallbackGuard

        include SessionLimitGate

        include SocialOmniauthCallbackFlow

        AUTHENTICATION_MODE = :deny_all

        declare_authentication_mode! :open, only: %i(omniauth failure)

        skip_before_action :apply_localization_preferences, only: %i(omniauth failure)
        skip_before_action :set_region, only: %i(omniauth failure)

        def omniauth
          super
        end

        def handle_omniauth_callback(auth)
          validate_social_auth_state!
          SocialAuth::VerifiedProviderAssertion.call(
            auth_hash: auth,
            expected_provider: params[:provider],
          )
          staff = find_staff_from_auth(auth)
          return redirect_staff_not_found(auth) unless staff

          clear_social_auth_intent!
          return redirect_login_not_allowed(staff) unless staff.login_allowed?

          login_and_redirect(staff, auth)
        end

        # GET /auth/failure
        def failure
          message = params[:message] || "unknown_error"
          clear_social_auth_intent!
          Rails.logger.info(Jit::LogEvent.format("sign.social.org.omniauth_failure", message: message))
          redirect_to(
            new_sign_org_sign_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        private

        def social_omniauth_callback_received_event
          "sign.social.org.omniauth.callback_received"
        end

        def social_omniauth_missing_auth_event
          "sign.social.org.omniauth.missing_auth_hash"
        end

        def social_omniauth_unexpected_error_event
          "sign.social.org.omniauth.unexpected_error"
        end

        def social_omniauth_failure_i18n_key
          "sign.org.social.sessions.create.failure"
        end

        def find_staff_from_auth(auth)
          staff = find_active_staff_by_google_identity(auth, intent: current_social_auth_intent)
          Rails.logger.debug(Jit::LogEvent.format("sign.social.org.omniauth.staff_found", staff_id: staff&.id)) if staff
          staff
        end

        def redirect_staff_not_found(auth)
          Rails.logger.info(
            Jit::LogEvent.format(
              "sign.social.org.omniauth.staff_not_found",
              provider: auth.provider,
              uid_present: OperatorGoogleIdentity.extract_uid(auth).present?,
            ),
          )
          clear_social_auth_intent!
          redirect_to(
            new_sign_org_sign_in_path,
            alert: I18n.t("sign.org.social.sessions.create.not_found"),
          )
        end

        def redirect_login_not_allowed(staff)
          Sign::Risk::Emitter.emit(
            "auth_failed", staff_id: staff.id, ip: request.remote_ip,
                           reason: "social_login_not_allowed",
          )
          redirect_to(
            new_sign_org_sign_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def login_and_redirect(staff, auth)
          login_result = log_in(
            staff,
            record_login_audit: true,
            audit_context: social_login_audit_context(auth),
          )
          provider_name = SocialIdentifiable.normalize_provider(auth.provider).humanize
          handle_login_result(login_result, provider_name)
        end

        def social_login_audit_context(auth)
          {
            auth_method: "social",
            provider: SocialIdentifiable.normalize_provider(auth.provider),
          }
        end

        def extract_email_from_auth(auth)
          email = auth.dig("info", "email") || auth.dig(:info, :email)
          email&.strip&.downcase
        end

        def find_active_staff_by_google_identity(auth, intent: "login")
          uid = OperatorGoogleIdentity.extract_uid(auth)
          provider = OperatorGoogleIdentity.provider_from_auth(auth)
          return nil if uid.blank? || provider.blank?

          staff = nil
          OrgPrincipalRecord.connected_to(role: :writing) do
            OrgPrincipalRecord.transaction do
              identity = OperatorGoogleIdentity.lock.find_by(uid: uid, provider: provider)
              if intent.to_s == "link"
                staff = link_google_identity!(identity, auth)
              elsif identity&.active?
                identity.update_from_auth_hash!(auth)
                staff = identity.staff
              end
            end
          end

          staff if staff&.status_id == OperatorStatus::ACTIVE
        end

        def link_google_identity!(identity, auth)
          staff = social_auth_user
          return nil unless staff
          return nil unless allowed_to?(:update?, staff, context: { user: staff })
          return nil if identity && identity.staff_id != staff.id

          identity ||= OperatorGoogleIdentity.find_or_create_from_auth_hash(auth)
          identity.staff = staff
          identity.status_id = OperatorGoogleIdentityStatus::ACTIVE
          identity.save!
          staff
        end

        def handle_login_result(result, provider_name)
          if result.is_a?(Hash)
            sign_in_result = sign_in_result_from_session_result(result)
            case sign_in_result.status
            when :session_limit_hard_reject
              render_session_limit_hard_reject(
                message: sign_in_result.message,
                http_status: sign_in_result.response_status,
              )
            when :session_limit_pending
              redirect_to(
                sign_in_result.redirect_to,
                notice: I18n.t("session_limit.restricted_notice"),
              )
            when :success
              redirect_to_sign_in_sequence!(
                notice: I18n.t("sign.org.social.sessions.create.success", provider: provider_name),
              )
            else
              redirect_to(
                new_sign_org_sign_in_path,
                alert: I18n.t("sign.org.social.sessions.create.failure"),
              )
            end
          else
            redirect_to_sign_in_sequence!(
              notice: I18n.t("sign.org.social.sessions.create.success", provider: provider_name),
            )
          end
        end

        def handle_unexpected_error(error, auth)
          Rails.logger.error(
            Jit::LogEvent.format(
              "sign.social.org.omniauth.unexpected_error",
              error_class: error.class.name,
              error_message: error.message,
              provider: auth&.provider,
              exception: error,
            ),
          )
          clear_social_auth_intent!
          redirect_to(
            new_sign_org_sign_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def social_auth_failure_redirect_path
          new_sign_org_sign_in_path
        end

        def social_auth_success_redirect_path
          sign_org_configuration_path
        end

        # Override to use org path instead of app path
        def reject_social_callback!(reason:, provider:, details: {})
          clear_social_state!
          Rails.logger.warn(
            Jit::LogEvent.format(
              "social_callback.rejected",
              source: "SocialCallbackGuard",
              surface: "org",
              phase: "callback",
              provider: provider,
              reason: reason,
              details: details,
            ),
          )
          redirect_to(
            new_sign_org_sign_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
            status: :forbidden,
          )
        end
      end
    end
  end
end
