# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Health
      class ReadiesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesCom

        def show
          show_ready
        end
      end
    end
  end
end
