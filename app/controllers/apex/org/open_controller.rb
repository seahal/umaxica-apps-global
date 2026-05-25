# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class OpenController < ApplicationController
      AUTHENTICATION_MODE = :open

      include ::RateLimit
      include ::Session

      include ::Preference::Global

      include ::Authentication::Operator

      include ActionPolicy::Controller

      include ::Oidc::SsoInitiator

      include ::ActorSupport

      include ::Finisher

      authorize :user, through: :current_operator

      layout "apex/org/application"

      allow_browser versions: :modern

      declare_authentication_mode! :open

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
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      def oidc_client_id = "apex_org"

      def oidc_sign_host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    end
  end
end
