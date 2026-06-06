# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Health
      class LivesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesOrg

        def show
          show_live
        end
      end
    end
  end
end
