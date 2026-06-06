# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Health
      class StartupsController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesSignApp

        def show
          show_startup
        end
      end
    end
  end
end
