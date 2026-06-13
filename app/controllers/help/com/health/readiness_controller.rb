# typed: false
# frozen_string_literal: true

module Help
  module Com
    module Health
      class ReadinessController < BareController
        include ::Health::CheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::Com

        def show
          render_probe(::Health::ReadinessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
