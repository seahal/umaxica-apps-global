# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Health
      class LivesController < BareController
        include ::HealthEndpoint

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::HealthProfilesCom

        def show
          show_live
        end
      end
    end
  end
end
