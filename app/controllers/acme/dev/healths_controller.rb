# typed: false
# frozen_string_literal: true

module Acme
  module Dev
    class HealthsController < BareController
      include ::HealthEndpoint

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::HealthProfilesApp

      def show
        show_health_snapshot
      end
    end
  end
end
