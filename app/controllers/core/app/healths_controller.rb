# typed: false
# frozen_string_literal: true

module Core
  module App
    class HealthsController < BareController
      include ::Health::Controller

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::App

      def show
        show_health_snapshot
      end
    end
  end
end
