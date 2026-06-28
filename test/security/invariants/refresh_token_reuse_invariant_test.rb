# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class RefreshTokenReuseInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      setup do
        ensure_client_token_reference_records!
        ClientToken.skip_callback(:validation, :before, :ensure_device_session_record)
      end

      teardown do
        ClientToken.set_callback(:validation, :before, :ensure_device_session_record)
      end

      test "refresh token reuse revokes only the compromised token family" do
        user = create_client
        original = ClientToken.create!(
          user: user,
          discarded_at: 1.day.from_now,
          purged_at: 2.days.from_now,
        )
        reused_refresh = original.rotate_refresh_token!
        rotated = SignRefreshTokenIssuer.call(refresh_token: reused_refresh).fetch(:token)

        other_family = ClientToken.create!(
          user: user,
          discarded_at: 1.day.from_now,
          purged_at: 2.days.from_now,
        )
        other_family.rotate_refresh_token!

        result = SignRefreshTokenIssuer.call(refresh_token: reused_refresh)

        assert_not result.success?
        assert_equal :refresh_token_reuse_detected, result.reason

        assert_operator original.reload.discarded_at, :<=, Time.current
        assert_operator rotated.reload.discarded_at, :<=, Time.current
        assert_not other_family.reload.revoked?,
                   "Reuse detection must not be confused with ordinary logout or revoke unrelated families"
      end

      test "ordinary current session revoke does not revoke the whole family" do
        user = create_client
        current = ClientToken.create!(
          user: user,
          discarded_at: 1.day.from_now,
          purged_at: 2.days.from_now,
        )
        refresh = current.rotate_refresh_token!
        sibling = SignRefreshTokenIssuer.call(refresh_token: refresh).fetch(:token)

        current.revoke!

        assert_predicate current.reload, :revoked?
        assert_not sibling.reload.revoked?,
                   "Ordinary logout/current-session revoke must not revoke the entire refresh family"
      end

      private

      def ensure_client_token_reference_records!
        ClientTokenStatus.ensure_defaults!
        ClientTokenKind.ensure_defaults!
        ClientTokenBindingMethod.ensure_defaults!
        ClientTokenDbscStatus.ensure_defaults!
      end

      def create_client
        ensure_user_reference_records!
        Client.create!(
          status_id: ClientStatus::NOTHING,
          visibility_id: ClientVisibility::USER,
          mfa_level_id: ClientMfaLevel::NOTHING,
          mfa_status_id: ClientMfaStatus::UNCONFIGURED,
        )
      end
    end
  end
end
