# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Health
      class LivesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesSignOrg

        def show
          show_live
        end
      end
    end
  end
end
