# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Health
      class StartupsController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Com

        def index
          render_probe(::Health::StartupCheck.call(profile: health_profile))
        end
      end
    end
  end
end
