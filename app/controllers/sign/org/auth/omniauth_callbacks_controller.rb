# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Auth
      # Controller for handling Google OAuth callbacks for staff sign-in.
      #
      # Routes:
      #   GET /auth/:provider/callback -> #omniauth
      #   GET /auth/failure            -> #failure
      #
      # Staff sign-in only (no sign-up):
      # - Extracts email from Google auth hash
      # - Looks up Staff via StaffEmail by that email
      # - Signs in the staff if found and active
      class OmniauthCallbacksController < Sign::Org::ApplicationController
        include SocialAuthConcern
        include SocialCallbackGuard
        include SessionLimitGate

        public_strict! only: %i(omniauth failure)

        skip_before_action :apply_localization_preferences, only: %i(omniauth failure)

        # GET/POST /auth/:provider/callback
        def omniauth
          auth = request.env["omniauth.auth"] || mock_auth_from_test_mode
          Rails.event.debug(
            "sign.social.org.omniauth.callback_received",
            provider: auth&.provider,
          )

          unless auth
            return handle_missing_auth
          end

          validate_social_auth_state!
          staff = find_staff_from_auth(auth)
          return redirect_staff_not_found(auth) unless staff

          clear_social_auth_intent!
          return redirect_login_not_allowed(staff) unless staff.login_allowed?

          login_and_redirect(staff, auth)
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        rescue StandardError => e
          handle_unexpected_error(e, auth)
        end

        # GET /auth/failure
        def failure
          message = params[:message] || "unknown_error"
          clear_social_auth_intent!
          Rails.event.record("sign.social.org.omniauth_failure", message: message)
          redirect_to(
            new_sign_org_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        private

        def verified_request?
          super || (action_name == "omniauth" && verified_social_callback_request?)
        end

        def handle_unverified_request
          if action_name == "omniauth"
            rejection = request.env["social_callback_guard.rejection"] || {
              reason: "csrf_unverified",
              provider: params.expect(:provider).to_s,
              details: {},
            }
            reject_social_callback!(**rejection)
          else
            super
          end
        end

        def handle_missing_auth
          Rails.event.error("sign.social.org.omniauth.missing_auth_hash")
          redirect_to(
            new_sign_org_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def find_staff_from_auth(auth)
          email = extract_email_from_auth(auth)
          staff = find_active_staff_by_google_email(email)
          Rails.event.debug("sign.social.org.omniauth.staff_found", staff_id: staff&.id) if staff
          staff
        end

        def redirect_staff_not_found(auth)
          email = extract_email_from_auth(auth)
          Rails.event.notify(
            "sign.social.org.omniauth.staff_not_found",
            provider: auth.provider,
            email_present: email.present?,
          )
          clear_social_auth_intent!
          redirect_to(
            new_sign_org_in_path,
            alert: I18n.t("sign.org.social.sessions.create.not_found"),
          )
        end

        def redirect_login_not_allowed(staff)
          Sign::Risk::Emitter.emit(
            "auth_failed", staff_id: staff.id, ip: request.remote_ip,
                           reason: "social_login_not_allowed",
          )
          redirect_to(
            new_sign_org_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def login_and_redirect(staff, auth)
          login_result = log_in(staff, record_login_audit: true)
          provider_name = SocialIdentifiable.normalize_provider(auth.provider).humanize
          handle_login_result(login_result, provider_name)
        end

        def extract_email_from_auth(auth)
          email = auth.dig("info", "email") || auth.dig(:info, :email)
          email&.strip&.downcase
        end

        def find_active_staff_by_google_email(email)
          return nil if email.blank?

          staff_email = nil
          OperatorRecord.connected_to(role: :writing) do
            staff_email = StaffEmail.find_by(address: email)
            if staff_email && !staff_email.undeletable?
              staff_email.update!(undeletable: true)
            end
          end

          staff = staff_email&.staff
          staff if staff&.status_id == StaffStatus::ACTIVE
        end

        # rubocop:disable Metrics/MethodLength
        def handle_login_result(result, provider_name)
          if result.is_a?(Hash) && result[:status] != :success
            case result[:status]
            when :session_limit_hard_reject
              render_session_limit_hard_reject(
                message: result[:message],
                http_status: result[:http_status],
              )
            when :session_limit_exceeded
              redirect_to(
                sign_org_in_session_path,
                notice: I18n.t("session_limit.restricted_notice"),
              )
            else
              redirect_to(
                new_sign_org_in_path,
                alert: I18n.t("sign.org.social.sessions.create.failure"),
              )
            end
          elsif result.is_a?(Hash) && result[:restricted]
            redirect_to(
              sign_org_in_session_path,
              notice: I18n.t("session_limit.restricted_notice"),
            )
          else
            if issue_bulletin!
              redirect_to(
                sign_org_in_bulletin_path(ri: params[:ri]),
                notice: I18n.t("sign.org.social.sessions.create.success", provider: provider_name),
              )
            else
              redirect_to(
                sign_org_root_path(ri: params[:ri]),
                notice: I18n.t("sign.org.social.sessions.create.success", provider: provider_name),
              )
            end
          end
        end

        # rubocop:enable Metrics/MethodLength

        def handle_unexpected_error(error, auth)
          Rails.event.error(
            "sign.social.org.omniauth.unexpected_error",
            error_class: error.class.name,
            error_message: error.message,
            provider: auth&.provider,
            exception: error,
          )
          clear_social_auth_intent!
          redirect_to(
            new_sign_org_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def mock_auth_from_test_mode
          return unless Rails.env.test?

          provider = params[:provider]
          return unless provider

          OmniAuth.config.mock_auth[provider.to_sym] || OmniAuth.config.mock_auth[provider.to_s]
        end

        def social_auth_failure_redirect_path
          new_sign_org_in_path
        end

        def social_auth_success_redirect_path
          sign_org_configuration_path
        end

        # Override to use org path instead of app path
        def reject_social_callback!(reason:, provider:, details: {})
          clear_social_state!
          Rails.event.warn(
            "social_callback.rejected",
            source: "SocialCallbackGuard",
            surface: "org",
            phase: "callback",
            provider: provider,
            reason: reason,
            details: details,
          )
          redirect_to(
            new_sign_org_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
            status: :forbidden,
          )
        end
      end
    end
  end
end
