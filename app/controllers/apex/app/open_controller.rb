# typed: false
# frozen_string_literal: true

module Apex
  module App
    class OpenController < BareController
      include ::Session

      include ::Preference::Global

      include ::Authentication::Client

      include ActionPolicy::Controller

      include ::Oidc::SsoInitiator

      include ::Finisher

      authorize :user, through: :current_client

      layout "apex/app/application"

      public_strict!

      before_action :set_preferences_cookie
      before_action :apply_localization_preferences

      def oidc_client_id = "apex_app"

      def oidc_sign_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    end
  end
end
