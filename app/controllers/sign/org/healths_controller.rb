# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class HealthsController < BareController
      include ::HealthCheckRendering

      AUTHENTICATION_MODE = :bare
      HEALTH_PROFILE = ::Health::Profiles::SignOrg

      def show
        render_snapshot(::Health::SnapshotCheck.call(profile: health_profile))
      end
    end
  end
end
