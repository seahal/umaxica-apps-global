# typed: false
# frozen_string_literal: true

module Sign
  module App
    class HealthsController < BareController
      include ::HealthEndpoint

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::HealthProfilesSignApp

      def show
        show_health_snapshot
      end
    end
  end
end
