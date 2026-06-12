# typed: false
# frozen_string_literal: true

module Sign
  module App
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::PreferenceGlobal
      # Adopt anonymous preference cookies into the signed-in user account after authentication.
      include ::PreferenceAdoption
      include ::AuthenticationClient
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthenticationCredentialInventoryReader
      include ::AuthorizationClient
      include ::VerificationClient
      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      # Note: RestrictedSessionGuard is still needed to enforce session expiration
      # and block expired restricted sessions on the session management page itself.
      include ::RestrictedSessionGuard
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: JitHostOriginEnv.trusted_origins(
                             ENV["ID_SERVICE_URL"],
                             ENV.fetch("SIGN_SERVICE_URL"),
                           ),
                           with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?

      # NOTE: Order matters (dependencies rely on this sequence)
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "sign_app_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(rule_name: "sign_app_default_web", retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      # Restricted session guard - explicitly enabled to handle expired sessions
      # and prevent access to non-allowed routes for restricted sessions
      before_action :enforce_restricted_session_guard!
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      private

      # Post-session landing belongs to acme/www.
      def after_login_path
        return oidc_authorization_after_login_path if oidc_authorization_login_challenge.present?

        acme_app_dashboard_url(ri: params[:ri], host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
      end

      def after_login_allows_other_host?
        true
      end

      def cross_host_redirect_allowed?
        true
      end

      def oidc_client_id
        "sign_app"
      end

      def oidc_sign_host
        ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
      end

      def oidc_acme_host
        ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
      end

      def oidc_authorization_login_challenge
        session[:oidc_authorization_login_challenge]
      end

      def oidc_authorization_after_login_path
        challenge = oidc_authorization_login_challenge
        result =
          OidcAuthorizationTransactionService.register_result!(
            surface: "app",
            login_challenge: challenge,
            actor: current_resource,
            session_ref: current_session_public_id,
            auth_method: Array(Actor.authn.access_claims&.dig("amr")).first || "unknown",
            acr: Actor.authn.access_claims&.dig("acr"),
        )
        result.resume_url
      ensure
        session.delete(:oidc_authorization_login_challenge)
      end
    end
  end
end
