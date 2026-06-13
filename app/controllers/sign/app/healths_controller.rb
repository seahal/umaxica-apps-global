# typed: false
# frozen_string_literal: true

module Sign
  module App
    class HealthsController < BareController
      include ::HealthCheckRendering

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::SignApp

      def show
        render_snapshot(::Health::SnapshotCheck.call(profile: health_profile))
      end
    end
  end
end
