# typed: false
# frozen_string_literal: true

module Sign
  module App
    class HealthController < BareController
      include ::Health::CheckRendering

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::SignApp

      def show
        render_snapshot(::Health::SnapshotCheck.call(profile: health_profile))
      end
    end
  end
end
