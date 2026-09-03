# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Health
      class LivenessesController < BareController
        include ::HealthCheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::SignOrg

        def index
          render_probe(::Health::LivenessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
