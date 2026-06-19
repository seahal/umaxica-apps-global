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
      class OmniauthCallbacksController < ::Sign::App::ApplicationController
        include SocialAuth

        include SocialCallbackGuard

        include SessionLimitGate

        include SocialOmniauthCallbackFlow

        AUTHENTICATION_MODE = :deny_all
        rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
        rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique
        before_action :verify_social_callback_request!, only: [:omniauth], raise: false

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
          Rails.logger.debug(JitLogEvent.format("sign.social.omniauth.validating_state"))
          validate_social_auth_state!
          SocialAuthVerifiedProviderAssertion.call(
            auth_hash: auth,
            expected_provider: params[:provider],
          )

          if SocialIdentifiable.normalize_provider(auth.provider) == "apple"
            Rails.logger.info(
              JitLogEvent.format(
                "social_auth.apple.form_post.received",
                surface: :app,
                region: params[:ri],
                flow_id: session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY],
                request_id: request.request_id,
                callback_path: request.path,
                origin_present: request.headers["Origin"].present?,
                origin_null: request.headers["Origin"] == "null",
                state_present: params[:state].present?,
                id_token_present: params[:id_token].present?,
                user_payload_present: params[:user].present?,
                candidate_present: session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY].present?,
              ),
            )
          end

          intent = current_social_auth_intent
          Rails.logger.debug(JitLogEvent.format("sign.social.omniauth.processing_callback", intent: intent))
          result = process_social_auth_callback
          return if performed?

          user = result[:user]

          Rails.logger.debug(
            JitLogEvent.format(
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
            JitLogEvent.format(
              "sign.social.omniauth.failure_callback",
              message: message,
              strategy: strategy,
            ),
          )

          failure_redirect_path = social_auth_failure_redirect_path

          if duplicate_google_callback_failure_after_success?(message, strategy)
            Rails.logger.info(
              JitLogEvent.format(
                "sign.social.omniauth.duplicate_callback_failure_ignored",
                message: message,
                strategy: strategy,
              ),
            )
            return redirect_to(social_auth_success_redirect_path)
          end

          Rails.logger.info(
            JitLogEvent.format(
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
            JitLogEvent.format(
              "sign.social.omniauth.handle_successful_auth",
              intent: intent,
              user_id: user&.id,
            ),
          )

          case intent
          when "link"
            handle_link_intent(provider_name)
          when "login"
            if user.blank? && identity.blank?
              handle_pending_social_sign_up_intent(provider_name, pt: pt)
              return
            end

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
          # try to create a sign_up_flow, and the second loser hits the
          # unique constraint on Client during finalization. The advisory
          # lock collapses the second arrival into a no-op
          # cycle-already-issued.
          with_social_sign_up_lock(identity) do
            cycle = sign_up_flow_locator.current || create_social_sign_up_flow!(user, identity, pt: pt)
            bind_social_sign_up_flow!(cycle, user, identity)
          end

          redirect_to(
            public_send(
              :"sign_app_sign_up_guard_#{SocialIdentifiable.normalize_provider(identity.provider)}_path",
              ri: params[:ri].presence || current_social_auth_ri,
              pt: pt.presence,
            ),
            notice: I18n.t("sign.app.social.sessions.create.success", provider: provider_name),
          )
        end

        def social_sign_up_required?(_user, existing_account)
          !existing_account
        end

        def handle_pending_social_sign_up_intent(provider_name, pt: nil)
          auth = request.env["omniauth.auth"]
          provider = SocialIdentifiable.normalize_provider(auth.provider)

          with_pending_social_sign_up_lock(provider, SocialAuthUidExtractor.call(auth_hash: auth)) do
            cycle = sign_up_flow_locator.current || create_pending_social_sign_up_flow!(provider, pt: pt)
            store_pending_social_signup_evidence!(cycle, auth)
            advance_pending_social_sign_up_flow!(cycle)
          end

          redirect_to(
            public_send(
              :"sign_app_sign_up_guard_#{provider}_path",
              ri: params[:ri].presence || current_social_auth_ri,
              pt: pt.presence,
            ),
            notice: I18n.t("sign.app.social.sessions.create.success", provider: provider_name),
          )
        end

        def with_pending_social_sign_up_lock(provider, uid, &)
          digest = pending_social_signup_uid_digest(provider: provider, uid: uid)
          AppTicketRecord.connected_to(role: :writing) do
            SignUpEmailPendingGuard.with_lock(
              namespace: "sign_up:social_callback",
              address_digest: "#{provider}:#{digest}",
              model_class: AppTicketRecord,
              &
            )
          end
        end

        def create_pending_social_sign_up_flow!(provider, pt: nil)
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpFlowStatus.ensure_defaults!
            cycle = ClientSignUpFlow.create!(
              principal_id: nil,
              status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
              step: "social_callback",
              nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: ClientSignUpFlow.default_ttl.from_now,
              entry_method: provider,
              social_provider: provider,
              return_to: path_from_signed_pt(signed_pt_token(pt)),
            )
            sign_up_flow_locator.issue!(cycle)
            session[:sign_app_up_sequence_id] = cycle.public_id
            cycle
          end
        end

        def store_pending_social_signup_evidence!(cycle, auth)
          provider = SocialIdentifiable.normalize_provider(auth.provider)
          uid = SocialAuthUidExtractor.call(auth_hash: auth)
          unless cycle.social_provider == provider
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
          end
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless cycle.entry_method == provider

          grant = social_signup_ceremony_grant_for(cycle, auth.provider)

          candidate = IdentitySocialCeremonyCandidateStore.store!(
            surface: "app",
            actor_ref: grant["actor_ref"],
            session_ref: grant["session_ref"],
            transaction_id: grant["transaction_id"],
            operation: "signup",
            provider: auth.provider,
            auth_hash: auth,
            expires_at: cycle.expires_at,
          )

          cycle.update!(
            completed_requirements: cycle.completed_requirements.merge(
              "social_signup" => {
                "candidate_ref" => candidate.ref,
                "candidate_digest" => candidate.digest,
                "provider" => provider,
                "uid_digest" => pending_social_signup_uid_digest(provider: provider, uid: uid),
                "grant_transaction_id" => grant["transaction_id"],
                "stored_at" => Time.current.iso8601,
              },
            ),
          )
        end

        def advance_pending_social_sign_up_flow!(cycle)
          result = SignUpStateMachine.call(
            ticket: cycle,
            event: :complete_social_callback,
            actor_context: Actor.authn,
          )
          return if result.success?

          Rails.logger.warn(
            JitLogEvent.format(
              "sign.social.omniauth.pending_social_signup_failed",
              status: result.status,
              errors: result.errors,
              ticket_status_id: cycle.status_id,
              ticket_step: cycle.step,
              entry_method: cycle.entry_method,
              social_provider: cycle.social_provider,
            ),
          )
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
        end

        def pending_social_signup_uid_digest(provider:, uid:)
          OpenSSL::HMAC.hexdigest(
            "SHA256",
            Rails.application.secret_key_base,
            [provider, uid].map(&:to_s).join(":"),
          )
        end

        def social_signup_ceremony_grant_for(cycle, provider)
          issuance = IdentitySocialCeremonyGrantIssuer.issue!(
            surface: "app",
            actor_ref: cycle.public_id,
            session_ref: cycle.public_id,
            operation: "signup",
            provider: provider,
            resource_ref: "sign_up",
            return_to: cycle.return_to,
          )
          IdentitySocialCeremonyGrant.decode(
            issuance.grant,
            issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
          )
        end

        def with_social_sign_up_lock(identity, &)
          if identity&.respond_to?(:uid) && identity.respond_to?(:provider) &&
              identity.uid.present? && identity.provider.present?
            digest = "#{SocialIdentifiable.normalize_provider(identity.provider)}:#{identity.uid}"
            AppTicketRecord.connected_to(role: :writing) do
              SignUpEmailPendingGuard.with_lock(
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

        def create_social_sign_up_flow!(user, identity, pt: nil)
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless user && identity

          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpFlowStatus.ensure_defaults!
            cycle = ClientSignUpFlow.create!(
              principal_id: nil,
              status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
              step: "social_callback",
              nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: ClientSignUpFlow.default_ttl.from_now,
              entry_method: SocialIdentifiable.normalize_provider(identity.provider),
              social_provider: SocialIdentifiable.normalize_provider(identity.provider),
              return_to: path_from_signed_pt(signed_pt_token(pt)),
            )
            sign_up_flow_locator.issue!(cycle)
            session[:sign_app_up_sequence_id] = cycle.public_id
            cycle
          end
        end

        def handle_link_intent(provider_name)
          Rails.logger.debug(
            JitLogEvent.format(
              "sign.social.omniauth.link_intent",
              message: "Redirecting to settings",
            ),
          )
          default_notice = I18n.t(
            "sign.app.social.sessions.link.default",
            provider: provider_name,
            default: "%{provider} linked",
          )
          redirect_to(
            sign_app_settings_path,
            notice: I18n.t(
              "sign.app.social.sessions.link.success",
              provider: provider_name,
              default: default_notice,
            ),
          )
        end

        def handle_login_intent(user, provider_name, existing_account, pt: nil)
          Rails.logger.debug(JitLogEvent.format("sign.social.omniauth.login_intent", message: "Signing in user"))
          if existing_account
            return reject_established_social_login_session_creation!(provider_name)
          end

          unless user&.login_allowed?
            return redirect_to(
              sign_app_sign_in_path,
              alert: I18n.t("sign.app.social.sessions.create.failure"),
            )
          end

          login_result = sign_in(user, pt: pt)

          if login_result.is_a?(Hash) && login_result[:status] != :success
            Rails.logger.warn(
              JitLogEvent.format(
                "sign.social.omniauth.login_failed",
                status: login_result[:status],
                user_id: user.id,
              ),
            )
            return handle_login_failure(login_result, provider_name, user)
          end

          if login_result.is_a?(Hash) && login_result[:restricted]
            return redirect_to(
              sign_app_sign_in_session_path,
              notice: I18n.t("sign.app.in.session.restricted_notice"),
            )
          end

          Rails.logger.debug(
            JitLogEvent.format(
              "sign.social.omniauth.login_successful",
              message: "Redirecting after login",
            ),
          )
          redirect_after_login(provider_name, existing_account, pt: pt)
        end

        def reject_established_social_login_session_creation!(provider_name)
          Rails.logger.warn(
            JitLogEvent.format(
              "sign.social.omniauth.established_login_session_creation_rejected",
              provider: provider_name,
            ),
          )
          redirect_to(
            sign_app_sign_in_path(ri: params[:ri].presence || current_social_auth_ri),
            alert: I18n.t("sign.app.social.sessions.create.failure"),
          )
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
            JitLogEvent.format(
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

        def bind_social_sign_up_flow!(cycle, user, identity)
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
            SignUpStateMachine.call(
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

        def sign_up_flow_locator
          SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
        end

        # Handle login failures (session limit, MFA required, etc.)
        def handle_login_failure(login_result, _provider_name, user = nil)
          SignRiskEmitter.emit(
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
            Rails.logger.debug(JitLogEvent.format("sign.social.omniauth.session_limit_exceeded"))
            redirect_to(
              sign_in_result.redirect_to,
              notice: I18n.t("sign.app.in.session.restricted_notice"),
            )
          when :mfa_required
            Rails.logger.debug(JitLogEvent.format("sign.social.omniauth.mfa_required"))
            safe_redirect_to(
              sign_in_result.redirect_to,
              fallback: sign_app_sign_in_path,
              notice: I18n.t("sign.app.in.mfa.required"),
            )
          else
            Rails.logger.warn(JitLogEvent.format("sign.social.omniauth.unknown_login_failure", status: status))
            redirect_to(
              sign_app_sign_in_path,
              alert: I18n.t("sign.app.social.sessions.create.failure"),
            )
          end
        end

        def social_auth_failure_redirect_path
          ri = params[:ri].presence || current_social_auth_ri

          if current_social_auth_entry == "sign_up"
            return sign_app_sign_up_path(ri: ri)
          end

          sign_app_sign_in_path(ri: ri)
        end

        def social_auth_success_redirect_path
          sign_app_settings_path
        end

        def duplicate_google_callback_failure_after_success?(message, strategy)
          message.to_s == "invalid_credentials" &&
            strategy.to_s == "google_app" &&
            logged_in?
        end

        def validate_social_auth_state!
          super
        end

        def current_social_auth_intent
          explicit_intent = session[SOCIAL_INTENT_SESSION_KEY]
          return explicit_intent if explicit_intent.present?

          "login"
        end
      end
    end
  end
end
