# typed: false
# frozen_string_literal: true

module Core
  module Com
    class RootsController < Core::Com::ApplicationController
      AUTHENTICATION_MODE = :open

      # Public landing page: skip the per-request preference create/rotate write
      # and DBSC registration header. DBSC issuance belongs to the dedicated
      # registration/verification endpoints, not idempotent page loads.
      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
        render template: "acme/com/roots/index"
      end
    end
  end
end
