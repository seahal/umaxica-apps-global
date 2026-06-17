# frozen_string_literal: true

require "test_helper"

class JitLogEventRedactionTest < ActiveSupport::TestCase
  test "formats redacted payloads" do
    json =
      JitLogEvent.format(
        "test.event",
        "email" => "person@example.com",
        "token" => "secret-token",
        "original_url" => "https://example.com/path?code=abc",
        "nested" => [{ "cookie" => "abc", "uid" => "user-123" }],
      )

    payload = JSON.parse(json)

    assert_equal "test.event", payload.fetch("event")
    assert_equal "[FILTERED]", payload.dig("data", "email")
    assert_equal "[FILTERED]", payload.dig("data", "token")
    assert_equal "https://example.com/path", payload.dig("data", "original_url")
    assert_equal "[FILTERED]", payload.dig("data", "nested", 0, "cookie")
    assert_equal "[FILTERED]", payload.dig("data", "nested", 0, "uid")
  end
end
