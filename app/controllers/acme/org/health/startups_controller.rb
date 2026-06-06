# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Health
      class StartupsController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesOrg

        def show
          show_startup
        end
      end
    end
  end
end
