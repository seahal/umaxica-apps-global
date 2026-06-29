# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

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

  test "wraps a non-Hash payload under a message key" do
    json = JitLogEvent.format("test.event", "boom: contact resolve failed", severity: "error")

    payload = JSON.parse(json)

    assert_equal "test.event", payload.fetch("event")
    assert_equal "boom: contact resolve failed", payload.dig("data", "message")
    assert_equal "error", payload.dig("data", "severity")
  end

  test "wraps an Exception payload under a message key with class and message attributes" do
    boom = RuntimeError.new("downstream unreachable")
    json = JitLogEvent.format("test.exception", boom, retryable: true)

    payload = JSON.parse(json)

    assert_equal "RuntimeError", payload.dig("data", "message", "class")
    assert_equal "downstream unreachable", payload.dig("data", "message", "message")
    assert payload.dig("data", "retryable")
  end
end
