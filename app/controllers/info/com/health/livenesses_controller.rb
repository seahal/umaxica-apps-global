# typed: false
# frozen_string_literal: true

module Info
  module Com
    module Health
      class LivenessesController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Com

        def index
          render_probe(::Health::LivenessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
