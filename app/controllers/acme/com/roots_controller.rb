# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class RootsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :open

      # Public landing page: skip the per-request preference create/rotate write
      # and DBSC registration header. DBSC issuance belongs to the dedicated
      # registration/verification endpoints, not idempotent page loads.
      # Mirrors Sign::Com::RootsController.
      skip_before_action :set_preferences_cookie, only: :index, raise: false

      def index
      end
    end
  end
end
