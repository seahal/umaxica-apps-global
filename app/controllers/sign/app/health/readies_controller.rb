# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Health
      class ReadiesController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::SignApp

        def show
          show_ready
        end
      end
    end
  end
end
