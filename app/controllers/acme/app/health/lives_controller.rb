# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Health
      class LivesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesApp

        def show
          show_live
        end
      end
    end
  end
end
