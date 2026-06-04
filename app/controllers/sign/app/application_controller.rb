# typed: false
# frozen_string_literal: true

module Sign
  module App
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::Preference::Global
      # Adopt anonymous preference cookies into the signed-in user account after authentication.
      include ::Preference::Adoption
      include ::Authentication::Client
      include ::Sign::ErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::Authentication::CredentialInventoryReader
      include ::Authorization::Client
      include ::Verification::Client
      include ActionPolicy::Controller
      # Note: RestrictedSessionGuard is still needed to enforce session expiration
      # and block expired restricted sessions on the session management page itself.
      include ::RestrictedSessionGuard
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV["ID_SERVICE_URL"],
                             ENV.fetch("SIGN_SERVICE_URL"),
                           ),
                           with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from Authentication::Base::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?

      # NOTE: Order matters (dependencies rely on this sequence)
      before_action :check_default_rate_limit
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
        acme_app_dashboard_url(ri: params[:ri], host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
      end

      def after_login_allows_other_host?
        true
      end
def cross_host_redirect_allowed?
  true
end
    end
  end
end
