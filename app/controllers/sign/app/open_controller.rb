# typed: false
# frozen_string_literal: true

module Sign
  module App
    class OpenController < BareController
      include ::Session
      include ::Preference::Global
      include ::Preference::Adoption
      include ::Preference::ResourceSync
      include ::Authentication::Client
      include ActionPolicy::Controller
      include ::ActorSupport
      include ::Finisher

      authorize :user, through: :current_client

      layout "sign/app/application"

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
    end
  end
end
