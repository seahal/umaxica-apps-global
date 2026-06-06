# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Health
      class LivesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesSignApp

        def show
          show_live
        end
      end
    end
  end
end
