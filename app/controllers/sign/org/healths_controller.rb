# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class HealthsController < BareController
      include ::Health::Controller

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::SignOrg

      def show
        show_health_snapshot
      end
    end
  end
end
