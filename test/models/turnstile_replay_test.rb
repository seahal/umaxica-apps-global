# typed: false
# frozen_string_literal: true

require "test_helper"

class TurnstileReplayTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "digest_token is deterministic and handles blank values" do
    assert_equal TurnstileReplay.digest_token("token"), TurnstileReplay.digest_token("token")
    assert_not_equal TurnstileReplay.digest_token("token"), TurnstileReplay.digest_token("other")
    assert_equal TurnstileReplay.digest_token(""), TurnstileReplay.digest_token(nil)
  end

  test "expired? observes the expiry boundary" do
    now = Time.zone.parse("2026-07-15 12:00:00")
    replay = TurnstileReplay.new(expires_at: now + 1.minute)

    travel_to(now) do
      assert_not replay.expired?
      travel 1.minute

      assert_predicate replay, :expired?
    end
  end

  test "required replay attributes are validated" do
    replay = TurnstileReplay.new

    assert_not replay.valid?
    assert_includes replay.errors.attribute_names, :ceremony_id
    assert_includes replay.errors.attribute_names, :token_digest
    assert_includes replay.errors.attribute_names, :expires_at
  end
end
