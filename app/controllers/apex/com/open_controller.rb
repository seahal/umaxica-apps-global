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

      include ::Finisher

      authorize :user, through: :current_visitor

      layout "apex/com/application"

      public_strict!

      before_action :set_preferences_cookie
      before_action :apply_localization_preferences

      def oidc_client_id = "apex_com"

      def oidc_sign_host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    end
  end
end
