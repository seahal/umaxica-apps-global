# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class OpenController < BareController
      include ::Session

      include ::Preference::Global

      include ::Authentication::Visitor

      include ActionPolicy::Controller

      include ::Oidc::SsoInitiator

      include ::ActorSupport

      include ::Finisher

      authorize :user, through: :current_visitor

      layout "apex/com/application"

      public_strict!

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

      def oidc_client_id = "apex_com"

      def oidc_sign_host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    end
  end
end
