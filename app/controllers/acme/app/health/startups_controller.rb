# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Health
      class StartupsController < BareController
        include ::Health::Controller

        AUTHENTICATION_MODE = :bare
        HEALTH_PROFILE = ::Health::Profiles::App

        def show
          show_startup
        end
      end
    end
  end
end
