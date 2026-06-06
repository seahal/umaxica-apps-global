# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Health
      class StartupsController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesSignOrg

        def show
          show_startup
        end
      end
    end
  end
end
