# typed: false
# frozen_string_literal: true

require "test_helper"

class TurnstileReplayStoreTest < ActiveSupport::TestCase
  test "consume! persists a turnstile replay record and returns true" do
    result = TurnstileReplayStore.consume!(
      token: "test-token",
      ceremony_id: "test-ceremony",
      action: "sign-in",
      hostname: "example.com",
      cdata: "test-cdata",
      expires_at: 1.hour.from_now,
    )

    assert result
    replay = TurnstileReplay.last

    assert_equal "test-ceremony", replay.ceremony_id
    assert_equal TurnstileReplay.digest_token("test-token"), replay.token_digest
    assert_equal "sign-in", replay.action
    assert_equal "example.com", replay.hostname
    assert_equal "test-cdata", replay.cdata
    assert replay.consumed_at
  end

  test "consume! raises RecordNotUnique for duplicate token digests" do
    TurnstileReplayStore.consume!(
      token: "dup-token",
      ceremony_id: "first-ceremony",
      action: "sign-in",
      hostname: "example.com",
      cdata: "cdata",
      expires_at: 1.hour.from_now,
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      TurnstileReplayStore.consume!(
        token: "dup-token",
        ceremony_id: "second-ceremony",
        action: "sign-in",
        hostname: "example.com",
        cdata: "cdata",
        expires_at: 1.hour.from_now,
      )
    end
  end
end
