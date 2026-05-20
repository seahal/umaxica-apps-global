# typed: false
# frozen_string_literal: true

module Apex
  module Org
    class OpenController < BareController
      include ::Session

      include ::Preference::Global

      include ::Authentication::Operator

      include ActionPolicy::Controller

      include ::Oidc::SsoInitiator

      include ::Finisher

      authorize :user, through: :current_operator

      layout "apex/org/application"

      public_strict!

      before_action :set_preferences_cookie
      before_action :apply_localization_preferences

      def oidc_client_id = "apex_org"

      def oidc_sign_host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    end
  end
end
