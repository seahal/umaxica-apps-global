# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class ApplicationController < ActionController::Base
      include ::RateLimit

      include ::Session

      include ::Preference::Global

      include ::Preference::Adoption # FIXME: I hate this line.

      include ::Authentication::Operator

      include ::Authorization::Operator

      include ::Verification::Operator

      include ActionPolicy::Controller # FIXME: I hate this line.

      include ::Oidc::SsoInitiator # FIXME: I hate this line.

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user

      allow_browser versions: :modern

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
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("APEX_STAFF_URL", "www.org.localhost"),
                           ),
                           with: :exception

      public

      def oidc_client_id
        "apex_org"
      end

      def oidc_sign_host
        ENV.fetch("ID_STAFF_URL", "id.org.localhost")
      end

      private
    end
  end
end
