# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Auth
      # Controller for handling OmniAuth callbacks (standard paths)
      #
      # Routes:
      #   GET  /auth/google_app/callback -> #omniauth
      #   POST /auth/apple/callback      -> #omniauth
      #   GET  /auth/failure             -> #failure
      #
      # This controller handles the OmniAuth callback, validates state,
      # and delegates to SocialAuthService for user creation/linking.
      #
      # State validation is applied to ALL providers (including Apple).
      # Apple sends state in POST body, Google sends in query string.
      # Both are accessible via params[:state].
      class OmniauthCallbacksController < Sign::App::ApplicationController
        include SocialAuthConcern
        include SocialCallbackGuard
        include SessionLimitGate
        include SocialOmniauthCallbackFlow

        # Allow unauthenticated access for login intent
        # For link intent, auth is checked in prepare_social_auth_intent!
        public_strict! only: %i(omniauth failure)

        # Skip preference before_actions that may interfere with OmniAuth callback
        skip_before_action :apply_localization_preferences, only: %i(omniauth failure)
        skip_before_action :set_region, only: %i(omniauth failure)

        def handle_omniauth_callback(auth)
          Rails.event.debug("sign.social.omniauth.validating_state")
          validate_social_auth_state!

          intent = current_social_auth_intent
          Rails.event.debug("sign.social.omniauth.processing_callback", intent: intent)
          result = process_social_auth_callback
          user = result[:user]

          Rails.event.debug(
            "sign.social.omniauth.callback_processed",
            user_id: user&.id,
            intent: intent,
            existing_account: result[:existing_account],
          )

          handle_successful_auth(
            user,
            intent.presence || "login",
            SocialIdentifiable.normalize_provider(auth.provider).humanize,
            result[:identity],
            existing_account: result[:existing_account],
            rt: result[:rt],
            entry: result[:entry],
          )
        end

        # GET /auth/failure
        # Handles OmniAuth failure (provider error, user cancellation, etc.)
        def failure
          message = params[:message] || "unknown_error"
          strategy = params[:strategy] || "unknown"

          Rails.event.debug(
            "sign.social.omniauth.failure_callback",
            message: message,
            strategy: strategy,
          )

          failure_redirect_path = social_auth_failure_redirect_path

          if duplicate_google_callback_failure_after_success?(message, strategy)
            Rails.event.info(
              "sign.social.omniauth.duplicate_callback_failure_ignored",
              message: message,
              strategy: strategy,
            )
            return redirect_to(social_auth_success_redirect_path)
          end

          Rails.event.record(
            "sign.social.omniauth_failure",
            message: message,
            strategy: strategy,
          )

          # Try to find a specific translation, fall back to generic
          failure_key = ["sign.app.social.sessions.failure", message].join(".")
          alert_message =
            if I18n.exists?(failure_key)
              I18n.t(failure_key)
            else
              I18n.t("sign.app.social.sessions.create.failure")
            end

          clear_social_auth_intent!
          redirect_to(failure_redirect_path, alert: alert_message)
        end

        private

        def social_omniauth_callback_requires_writing_role?
          true
        end

        def social_omniauth_callback_received_payload(auth)
          super.merge(
            uid: auth&.uid&.first(8),
            logged_in: logged_in?,
          )
        end

        def handle_successful_auth(user, intent, provider_name, _identity, existing_account: nil, rt: nil, entry: nil)
          Rails.event.debug(
            "sign.social.omniauth.handle_successful_auth",
            intent: intent,
            user_id: user&.id,
          )

          case intent
          when "link"
            handle_link_intent(provider_name)
          when "login"
            if entry == "sign_up" && !existing_account
              handle_social_sign_up_intent(user, provider_name, rt: rt)
            else
              handle_login_intent(user, provider_name, existing_account, rt: rt)
            end
          else
            handle_login_intent(user, provider_name, existing_account, rt: rt)
          end
        end

        def handle_social_sign_up_intent(user, provider_name, rt: nil)
          cycle = sign_up_cycle_locator.current
          unless cycle
            return redirect_to(
              new_sign_app_up_path(ri: params[:ri].presence || current_social_auth_ri),
              alert: I18n.t("sign.app.social.sessions.create.failure"),
            )
          end

          bind_social_sign_up_cycle!(cycle, user)
          redirect_to(
            sign_app_up_guardrail_path(
              ri: params[:ri].presence || current_social_auth_ri,
              rt: rt.presence,
            ),
            notice: I18n.t("sign.app.social.sessions.create.success", provider: provider_name),
          )
        end

        def handle_link_intent(provider_name)
          Rails.event.debug("sign.social.omniauth.link_intent", message: "Redirecting to configuration")
          default_notice = I18n.t(
            "sign.app.social.sessions.link.default",
            provider: provider_name,
            default: "%{provider} linked",
          )
          redirect_to(
            sign_app_configuration_path,
            notice: I18n.t(
              "sign.app.social.sessions.link.success",
              provider: provider_name,
              default: default_notice,
            ),
          )
        end

        def handle_login_intent(user, provider_name, existing_account, rt: nil)
          Rails.event.debug("sign.social.omniauth.login_intent", message: "Signing in user")
          unless user&.login_allowed?
            return redirect_to(
              new_sign_app_in_path,
              alert: I18n.t("sign.app.social.sessions.create.failure"),
            )
          end

          login_result = sign_in(user, rt: rt)

          if login_result.is_a?(Hash) && login_result[:status] != :success
            Rails.event.warn(
              "sign.social.omniauth.login_failed",
              status: login_result[:status],
              user_id: user.id,
            )
            return handle_login_failure(login_result, provider_name, user)
          end

          if login_result.is_a?(Hash) && login_result[:restricted]
            return redirect_to(
              sign_app_in_session_path,
              notice: I18n.t("sign.app.in.session.restricted_notice"),
            )
          end

          Rails.event.debug("sign.social.omniauth.login_successful", message: "Redirecting after login")
          redirect_after_login(provider_name, existing_account, rt: rt)
        end

        def redirect_after_login(provider_name, existing_account, rt: nil)
          if existing_account
            redirect_for_existing_account(provider_name, rt: rt)
          else
            redirect_for_new_account(provider_name, rt: rt)
          end
        end

        def redirect_for_existing_account(provider_name, rt: nil)
          redirect_to_sign_in_sequence!(
            rt: rt,
            notice: I18n.t(
              "sign.app.social.sessions.create.already_registered",
              provider: provider_name,
            ),
          )
        end

        def redirect_for_new_account(provider_name, rt: nil)
          redirect_to_sign_in_sequence!(
            rt: rt,
            notice: I18n.t("sign.app.social.sessions.create.success", provider: provider_name),
          )
        end

        def sign_in(user, rt: nil)
          result = establish_signed_in_session!(
            user, rt: rt, ri: params[:ri], auth_method: "social",
                  audit_context: social_login_audit_context,
          )
          Rails.event.debug("sign.social.omniauth.sign_in_result", result: result.inspect)
          result
        end

        def social_login_audit_context
          auth = request.env["omniauth.auth"]
          provider = SocialIdentifiable.normalize_provider(auth&.provider)
          context = { auth_method: "social" }
          context[:provider] = provider if provider.present?
          context
        end

        def bind_social_sign_up_cycle!(cycle, user)
          auth = request.env["omniauth.auth"]
          identity = social_identity_for(user, auth&.provider)
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity

          AppTicketRecord.connected_to(role: :writing) do
            cycle.update!(
              principal_id: user.id,
              pending_contact_type: "social_identity",
              pending_contact_id: identity&.id,
              social_provider: SocialIdentifiable.normalize_provider(auth&.provider),
            )
            SignUp::StateMachine.call(
              ticket: cycle,
              event: :complete_social_callback,
              actor_context: Actor.authentication,
            ).tap do |result|
              raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced
            end
          end
          store_social_sign_up_sequence_id(cycle)
        end

        def store_social_sign_up_sequence_id(cycle)
          session[:sign_app_up_sequence_id] = cycle.public_id
        rescue ActionDispatch::Request::Session::DisabledSessionError
          nil
        end

        def social_identity_for(user, provider)
          case SocialIdentifiable.normalize_provider(provider)
          when "google"
            user.user_social_google
          when "apple"
            user.user_social_apple
          end
        end

        def sign_up_cycle_locator
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpCycle)
        end

        # Handle login failures (session limit, MFA required, etc.)
        def handle_login_failure(login_result, _provider_name, user = nil)
          Sign::Risk::Emitter.emit(
            "auth_failed", user_id: user&.id, ip: request.remote_ip,
                           reason: "social_login_failed",
          ) if user
          sign_in_result = sign_in_result_from_session_result(login_result, actor: user)
          status = sign_in_result.status

          case status
          when :session_limit_hard_reject
            render_session_limit_hard_reject(
              message: sign_in_result.message,
              http_status: sign_in_result.response_status,
            )
          when :session_limit_pending
            Rails.event.debug("sign.social.omniauth.session_limit_exceeded")
            redirect_to(
              sign_in_result.redirect_to,
              notice: I18n.t("sign.app.in.session.restricted_notice"),
            )
          when :mfa_required
            Rails.event.debug("sign.social.omniauth.mfa_required")
            safe_redirect_to(
              sign_in_result.redirect_to,
              fallback: new_sign_app_in_path,
              notice: I18n.t("sign.app.in.mfa.required"),
            )
          else
            Rails.event.warn("sign.social.omniauth.unknown_login_failure", status: status)
            redirect_to(
              new_sign_app_in_path,
              alert: I18n.t("sign.app.social.sessions.create.failure"),
            )
          end
        end

        def social_auth_failure_redirect_path
          ri = params[:ri].presence || current_social_auth_ri

          if current_social_auth_entry == "sign_up"
            return new_sign_app_up_path(ri: ri)
          end

          new_sign_app_in_path(ri: ri)
        end

        def social_auth_success_redirect_path
          sign_app_configuration_path
        end

        def duplicate_google_callback_failure_after_success?(message, strategy)
          message.to_s == "invalid_credentials" &&
            strategy.to_s == "google_app" &&
            logged_in?
        end

        def validate_social_auth_state!
          intent = current_social_auth_intent
          if intent == "link" && auto_link_allowed? && logged_in?
            session[SOCIAL_FLOW_ID_SESSION_KEY] ||= SecureRandom.hex(16)
            session[SOCIAL_USER_ID_SESSION_KEY] ||= current_resource&.id
            session[SOCIAL_STARTED_AT_SESSION_KEY] ||= Time.current.to_i
            session[SOCIAL_PROVIDER_SESSION_KEY] ||= params[:provider]
          end

          super
        end

        # Override to support auto-link when user is already logged in
        # IMPORTANT: This ensures ClientSocialApple/ClientSocialGoogle is created and linked to current_client
        # Without this, callback defaults to "login" intent and creates a NEW user instead
        def current_social_auth_intent
          explicit_intent = session[SOCIAL_INTENT_SESSION_KEY]

          # If explicit intent is set (via /social/auth/:provider/continue), use it
          return explicit_intent if explicit_intent.present?

          # Auto-link: if user is logged in and no explicit intent, default to "link"
          # This handles the case where user clicks Apple Sign In while already logged in
          if logged_in?
            session[SOCIAL_INTENT_SESSION_KEY] = "link"
            if auto_link_allowed?
              session[SOCIAL_USER_ID_SESSION_KEY] = current_resource&.id
              session[SOCIAL_STARTED_AT_SESSION_KEY] ||= Time.current.to_i
              session[SOCIAL_FLOW_ID_SESSION_KEY] ||= SecureRandom.hex(16)
              session[SOCIAL_PROVIDER_SESSION_KEY] ||= params[:provider]
            end
            return "link"
          end

          # Default: login flow for non-logged-in users
          "login"
        end

        def auto_link_allowed?
          request.get? || request.head?
        end
      end
    end
  end
end
