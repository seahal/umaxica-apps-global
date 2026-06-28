# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class WithdrawnResourceRefreshInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      test "active resources are refreshable" do
        resource = create_client

        assert_refreshable resource
      end

      test "closing resources are not refreshable" do
        resource = create_client
        resource.update!(withdrawal_started_at: 1.hour.ago)

        assert_not_refreshable resource
      end

      test "suspended resources are not refreshable" do
        resource = create_client
        resource.update!(
          withdrawal_started_at: 2.hours.ago,
          deactivated_at: 1.hour.ago,
          discarded_at: 1.day.from_now,
          purged_at: 31.days.from_now,
        )

        assert_not_refreshable resource
      end

      test "terminated resources are not refreshable" do
        resource = create_client
        resource.update_columns(
          withdrawal_started_at: 3.hours.ago,
          deactivated_at: 2.hours.ago,
          discarded_at: 2.hours.ago,
          purged_at: 1.hour.ago,
          terminated_at: 30.minutes.ago,
          withdrawn_at: 30.minutes.ago,
        )

        assert_not_refreshable resource
      end

      private

      def create_client
        ensure_user_reference_records!
        Client.create!(
          status_id: ClientStatus::NOTHING,
          visibility_id: ClientVisibility::USER,
          mfa_level_id: ClientMfaLevel::NOTHING,
          mfa_status_id: ClientMfaStatus::UNCONFIGURED,
        )
      end

      def assert_refreshable(resource)
        assert controller.send(:refreshable_resource?, resource, allow_suspended: false)
      end

      def assert_not_refreshable(resource)
        assert_not controller.send(:refreshable_resource?, resource, allow_suspended: false)
      end

      def controller
        @controller ||= Auth::App::ApplicationController.new
      end
    end
  end
end
