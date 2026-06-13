# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Health
      class ReadinessController < BareController
        include ::Health::CheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::SignCom

        def show
          render_probe(::Health::ReadinessCheck.call(profile: health_profile))
        end
      end
    end
  end
end
