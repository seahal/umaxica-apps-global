# typed: false
# frozen_string_literal: true

module Base
  module App
    module Health
      class StartupController < BareController
        include ::Health::CheckRendering

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::App

        def show
          render_probe(::Health::StartupCheck.call(profile: health_profile))
        end
      end
    end
  end
end
