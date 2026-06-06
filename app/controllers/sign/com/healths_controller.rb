# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class HealthsController < BareController
      include ::Health::Controller

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::SignCom

      def show
        show_health_snapshot
      end
    end
  end
end
