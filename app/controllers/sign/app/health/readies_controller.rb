# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Health
      class ReadiesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesSignApp

        def show
          show_ready
        end
      end
    end
  end
end
