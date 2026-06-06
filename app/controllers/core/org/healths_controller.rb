# typed: false
# frozen_string_literal: true

module Core
  module Org
    class HealthsController < BareController
      include ::Health::Controller

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::Org

      def show
        show_health_snapshot
      end
    end
  end
end
