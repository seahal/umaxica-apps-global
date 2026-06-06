# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::JumpRtReturnVerification

      include ::Session

      include ::PreferenceGlobal

      include ::PreferenceAdoption # FIXME: I hate this line.

      include ::AuthenticationOperator
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit

      include ::AuthorizationOperator

      include ::VerificationOperator

      include ActionPolicy::Controller # FIXME: I hate this line.
      include ::RestrictedSessionGuard

      include ::OidcSsoInitiator # FIXME: I hate this line.

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_operator, :logged_in?, :active_operator?, :logged_in_operator?

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: explicit RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> side-effect reflection -> Verification -> AuthZ
      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "acme_org_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(rule_name: "acme_org_default_web", retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region

      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_color_theme
      before_action :enforce_restricted_session_guard!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: JitHostOriginEnv.trusted_origins(
                             ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
                           ),
                           with: :exception

      public

      def oidc_client_id
        "acme_org"
      end

      def oidc_sign_host
        ENV.fetch("ID_STAFF_URL", "id.org.localhost")
      end

      private

      def actor_verification_path(**args)
        acme_org_verification_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
