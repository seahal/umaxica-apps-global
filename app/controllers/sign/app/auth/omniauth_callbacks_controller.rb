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

        AUTHENTICATION_MODE = :deny_all

        # Allow unauthenticated access for login intent
        # For link intent, auth is checked in prepare_social_auth_intent!
        declare_authentication_mode! :open, only: %i(omniauth failure)

        # Skip preference before_actions that may interfere with OmniAuth callback
        skip_before_action :apply_localization_preferences, only: %i(omniauth failure)
        skip_before_action :set_region, only: %i(omniauth failure)

        def omniauth
          super
        end

        def handle_omniauth_callback(auth)
          Rails.logger.debug(Jit::LogEvent.format("sign.social.omniauth.validating_state"))
          validate_social_auth_state!
          SocialAuth::VerifiedProviderAssertion.call(
            auth_hash: auth,
            expected_provider: params[:provider],
          )

          intent = current_social_auth_intent
          Rails.logger.debug(Jit::LogEvent.format("sign.social.omniauth.processing_callback", intent: intent))
          result = process_social_auth_callback
          user = result[:user]

          Rails.logger.debug(
            Jit::LogEvent.format(
              "sign.social.omniauth.callback_processed",
              user_id: user&.id,
              intent: intent,
              existing_account: result[:existing_account],
            ),
          )

          handle_successful_auth(
            user,
            intent.presence || "login",
            SocialIdentifiable.normalize_provider(auth.provider).humanize,
            result[:identity],
            existing_account: result[:existing_account],
            pt: result[:pt],
          )
        end

        # GET /auth/failure
        # Handles OmniAuth failure (provider error, user cancellation, etc.)
        def failure
          message = params[:message] || "unknown_error"
          strategy = params[:strategy] || "unknown"

          Rails.logger.debug(
            Jit::LogEvent.format(
              "sign.social.omniauth.failure_callback",
              message: message,
              strategy: strategy,
            ),
          )

          failure_redirect_path = social_auth_failure_redirect_path

          if duplicate_google_callback_failure_after_success?(message, strategy)
            Rails.logger.info(
              Jit::LogEvent.format(
                "sign.social.omniauth.duplicate_callback_failure_ignored",
                message: message,
                strategy: strategy,
              ),
            )
            return redirect_to(social_auth_success_redirect_path)
          end

          Rails.logger.info(
            Jit::LogEvent.format(
              "sign.social.omniauth_failure",
              message: message,
              strategy: strategy,
            ),
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

        def handle_successful_auth(user, intent, provider_name, identity, existing_account: nil, pt: nil, entry: nil)
          _ = entry
          Rails.logger.debug(
            Jit::LogEvent.format(
              "sign.social.omniauth.handle_successful_auth",
              intent: intent,
              user_id: user&.id,
            ),
          )

          case intent
          when "link"
            handle_link_intent(provider_name)
          when "login"
            if social_sign_up_required?(user, existing_account)
              handle_social_sign_up_intent(user, provider_name, identity, pt: pt)
            else
              handle_login_intent(user, provider_name, existing_account, pt: pt)
            end
          else
            handle_login_intent(user, provider_name, existing_account, pt: pt)
          end
        end

        def handle_social_sign_up_intent(user, provider_name, identity, pt: nil)
          # Two callbacks for the same social identity (provider + uid) can
          # arrive simultaneously (e.g. user double-clicks the consent button
          # or replays a stale tab). Without serialization, both pass the
          # "no existing account" check, both fall into this branch, both
          # try to create a sign_up_cycle, and the second loser hits the
          # unique constraint on Client during finalization. The advisory
          # lock collapses the second arrival into a no-op
          # cycle-already-issued.
          with_social_sign_up_lock(identity) do
            cycle = sign_up_cycle_locator.current || create_social_sign_up_cycle!(user, identity, pt: pt)
            bind_social_sign_up_cycle!(cycle, user, identity)
          end

          redirect_to(
            sign_app_up_guardrail_path(
              ri: params[:ri].presence || current_social_auth_ri,
              pt: pt.presence,
            ),
            notice: I18n.t("sign.app.social.sessions.create.success", provider: provider_name),
          )
        end

        def social_sign_up_required?(user, existing_account)
          !existing_account || user&.birthdate.blank?
        end

        def with_social_sign_up_lock(identity, &)
          if identity&.respond_to?(:uid) && identity.respond_to?(:provider) &&
              identity.uid.present? && identity.provider.present?
            digest = "#{SocialIdentifiable.normalize_provider(identity.provider)}:#{identity.uid}"
            AppTicketRecord.connected_to(role: :writing) do
              SignUp::EmailPendingGuard.with_lock(
                namespace: "sign_up:social_callback",
                address_digest: digest,
                model_class: AppTicketRecord,
                &
              )
            end
          else
            yield
          end
        end

        def create_social_sign_up_cycle!(user, identity, pt: nil)
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless user && identity

          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpCycleStatus.ensure_defaults!
            cycle = ClientSignUpCycle.create!(
              principal_id: nil,
              status_id: ClientSignUpCycleStatus::SOCIAL_CALLBACK_PENDING,
              step: "social_callback",
              nonce_digest: ClientSignUpCycle.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: ClientSignUpCycle.default_ttl.from_now,
              entry_method: SocialIdentifiable.normalize_provider(identity.provider),
              social_provider: SocialIdentifiable.normalize_provider(identity.provider),
              return_to: path_from_signed_pt(signed_pt_token(pt)),
            )
            sign_up_cycle_locator.issue!(cycle)
            session[:sign_app_up_sequence_id] = cycle.public_id
            cycle
          end
        end

        def handle_link_intent(provider_name)
          Rails.logger.debug(
            Jit::LogEvent.format(
              "sign.social.omniauth.link_intent",
              message: "Redirecting to configuration",
            ),
          )
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

        def handle_login_intent(user, provider_name, existing_account, pt: nil)
          Rails.logger.debug(Jit::LogEvent.format("sign.social.omniauth.login_intent", message: "Signing in user"))
          unless user&.login_allowed?
            return redirect_to(
              new_sign_app_in_path,
              alert: I18n.t("sign.app.social.sessions.create.failure"),
            )
          end

          login_result = sign_in(user, pt: pt)

          if login_result.is_a?(Hash) && login_result[:status] != :success
            Rails.logger.warn(
              Jit::LogEvent.format(
                "sign.social.omniauth.login_failed",
                status: login_result[:status],
                user_id: user.id,
              ),
            )
            return handle_login_failure(login_result, provider_name, user)
          end

          if login_result.is_a?(Hash) && login_result[:restricted]
            return redirect_to(
              sign_app_in_session_path,
              notice: I18n.t("sign.app.in.session.restricted_notice"),
            )
          end

          Rails.logger.debug(
            Jit::LogEvent.format(
              "sign.social.omniauth.login_successful",
              message: "Redirecting after login",
            ),
          )
          redirect_after_login(provider_name, existing_account, pt: pt)
        end

        def redirect_after_login(provider_name, existing_account, pt: nil)
          if existing_account
            redirect_for_existing_account(provider_name, pt: pt)
          else
            redirect_for_new_account(provider_name, pt: pt)
          end
        end

        def redirect_for_existing_account(provider_name, pt: nil)
          redirect_to_sign_in_sequence!(
            pt: pt,
            notice: I18n.t(
              "sign.app.social.sessions.create.already_registered",
              provider: provider_name,
            ),
          )
        end

        def redirect_for_new_account(provider_name, pt: nil)
          redirect_to_sign_in_sequence!(
            pt: pt,
            notice: I18n.t("sign.app.social.sessions.create.success", provider: provider_name),
          )
        end

        def sign_in(user, pt: nil)
          result = establish_signed_in_session!(
            user, pt: pt, ri: params[:ri], auth_method: "social",
                  audit_context: social_login_audit_context,
          )
          Rails.logger.debug(
            Jit::LogEvent.format(
              "sign.social.omniauth.sign_in_result",
              **social_login_result_log_payload(result),
            ),
          )
          result
        end

        def social_login_result_log_payload(result)
          return { result_class: result.class.name } unless result.is_a?(Hash)

          payload = {
            status: result[:status],
            restricted: result[:restricted],
            session_management_required: result[:session_management_required],
            token_type: result[:token_type],
            expires_in: result[:expires_in],
          }
          dbsc = result[:dbsc]
          if dbsc.is_a?(Hash)
            payload[:dbsc] = {
              binding_method: dbsc[:binding_method],
              status: dbsc[:status],
              session_id_present: dbsc[:session_id].present?,
            }
          end
          payload.compact
        end

        def social_login_audit_context
          auth = request.env["omniauth.auth"]
          provider = SocialIdentifiable.normalize_provider(auth&.provider)
          context = { auth_method: "social" }
          context[:provider] = provider if provider.present?
          context
        end

        def bind_social_sign_up_cycle!(cycle, user, identity)
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity
          unless identity.persisted? && identity.id.present?
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
          end
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity.user_id == user.id
          unless SocialIdentifiable.normalize_provider(identity.provider) == cycle.social_provider
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
          end

          AppTicketRecord.connected_to(role: :writing) do
            cycle.update!(
              principal_id: user.id,
              pending_contact_type: "social_identity",
              pending_contact_id: identity&.id,
              social_provider: SocialIdentifiable.normalize_provider(identity.provider),
            )
            SignUp::StateMachine.call(
              ticket: cycle,
              event: :complete_social_callback,
              actor_context: Actor.authn,
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
            Rails.logger.debug(Jit::LogEvent.format("sign.social.omniauth.session_limit_exceeded"))
            redirect_to(
              sign_in_result.redirect_to,
              notice: I18n.t("sign.app.in.session.restricted_notice"),
            )
          when :mfa_required
            Rails.logger.debug(Jit::LogEvent.format("sign.social.omniauth.mfa_required"))
            safe_redirect_to(
              sign_in_result.redirect_to,
              fallback: new_sign_app_in_path,
              notice: I18n.t("sign.app.in.mfa.required"),
            )
          else
            Rails.logger.warn(Jit::LogEvent.format("sign.social.omniauth.unknown_login_failure", status: status))
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
