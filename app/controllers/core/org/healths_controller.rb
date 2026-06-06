# typed: false
# frozen_string_literal: true

module Core
  module Org
    class HealthsController < BareController
      include ::HealthEndpoint

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::HealthProfilesOrg

      def show
        show_health_snapshot
      end
    end
  end
end
