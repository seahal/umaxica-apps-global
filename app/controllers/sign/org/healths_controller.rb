# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class HealthsController < BareController
      include ::HealthEndpoint

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::HealthProfilesSignOrg

      def show
        show_health_snapshot
      end
    end
  end
end
