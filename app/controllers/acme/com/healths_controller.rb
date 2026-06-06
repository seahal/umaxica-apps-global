# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class HealthsController < BareController
      include ::HealthEndpoint

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::HealthProfilesCom

      def show
        show_health_snapshot
      end
    end
  end
end
