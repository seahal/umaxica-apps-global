# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::Preference::Global
      include ::Preference::Adoption
      include ::Authentication::Operator
      include ::Sign::ErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::Authentication::CredentialInventoryReader
      include ::Authorization::Operator
      include ::Verification::Operator
      include ActionPolicy::Controller
      include ::RestrictedSessionGuard
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
                           ),
                           with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from Authentication::Base::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_operator, :logged_in?, :active_operator?, :logged_in_operator?

      # Restricted session guard - explicitly enabled to block restricted sessions
      # from accessing routes other than /in/session
      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> side-effect reflection -> Verification -> AuthZ
      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      before_action :enforce_restricted_session_guard!
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      private

      # Redirect logged-in users from guest-only pages to the configuration page.
      # Overrides Authentication::Base#after_login_path. ri is added automatically via default_url_options.
      def after_login_path
        sign_org_dashboard_path
      end
    end
  end
end
