# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Health
      class StartupsController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::SignApp

        def show
          show_startup
        end
      end
    end
  end
end
