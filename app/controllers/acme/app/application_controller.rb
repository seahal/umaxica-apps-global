# typed: false
# frozen_string_literal: true

module Acme
  module App
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::JumpRt::ReturnVerification

      include ::Session

      include ::Preference::Global

      include ::Preference::Adoption # FIXME: I hate this line.

      include ::Authentication::Client
      include ::Sign::ErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit

      include ::Authorization::Client

      include ::Verification::Client

      include ActionPolicy::Controller # FIXME: I hate this line.
      include ::RestrictedSessionGuard

      include ::Oidc::SsoInitiator # FIXME: I hate this line.

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from Authentication::Base::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> side-effect reflection -> Verification -> AuthZ
      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie # FIXME: I hate this line.
      before_action :resolve_param_context # FIXME: I hate this line.
      before_action :set_region # FIXME: I hate this line.
      before_action :set_locale # FIXME: I hate this line.
      before_action :set_timezone # FIXME: I hate this line.

      before_action :transparent_refresh_access_token, unless: -> { request.format.json? } # FIXME: I hate this line.
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_color_theme # FIXME: I hate this line.
      before_action :enforce_withdrawal_gate! # FIXME: I hate this line.
      before_action :enforce_restricted_session_guard!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
                             ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
                           ),
                           with: :exception

      public

      def oidc_client_id
        "acme_app"
      end

      def oidc_sign_host
        ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end

      private

      def actor_verification_path(**args)
        acme_app_verification_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
