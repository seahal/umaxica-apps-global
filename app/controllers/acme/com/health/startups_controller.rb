# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Health
      class StartupsController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesCom

        def show
          show_startup
        end
      end
    end
  end
end
