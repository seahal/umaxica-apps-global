# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Health
      class StartupsController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Org

        def index
          render_probe(::Health::StartupCheck.call(profile: health_profile))
        end
      end
    end
  end
end
