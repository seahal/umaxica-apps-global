# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Health
      class StartupsController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesSignCom

        def show
          show_startup
        end
      end
    end
  end
end
