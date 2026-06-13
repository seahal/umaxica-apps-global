# typed: false
# frozen_string_literal: true

module News
  module Com
    class HealthController < BareController
      include ::Health::CheckRendering

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::Com

      def show
        render_snapshot(::Health::SnapshotCheck.call(profile: health_profile))
      end
    end
  end
end
