# typed: false
# frozen_string_literal: true

module Core
  module Org
    class RootsController < Core::Org::ApplicationController
      AUTHENTICATION_MODE = :open

      # Public landing page: skip the per-request preference create/rotate write
      # and DBSC registration header. DBSC issuance belongs to the dedicated
      # registration/verification endpoints, not idempotent page loads.
      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
        render template: "acme/org/roots/index"
      end
    end
  end
end
