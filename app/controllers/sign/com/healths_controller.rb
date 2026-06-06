# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class HealthsController < BareController
      include ::HealthEndpoint

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::HealthProfilesSignCom

      def show
        show_health_snapshot
      end
    end
  end
end
