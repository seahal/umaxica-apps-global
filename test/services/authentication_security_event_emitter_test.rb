# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationSecurityEventEmitterTest < ActiveSupport::TestCase
  test "emits known event types with redacted payloads" do
    logged = []

    Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message) }) do
      AuthenticationSecurityEventEmitter.emit(
        "rate_limit.exceeded",
        severity: "warning",
        reason_code: "telephone_verification_rate_limit",
        token: "raw-token",
        verifier: "raw-verifier",
        challenge: "raw-challenge",
        totp_secret: "raw-totp-secret",
        recovery_secret: "raw-recovery-secret",
        cookie: "raw-cookie",
      )
    end

    event = logged.fetch(0)
    data = event.fetch("data")

    assert_equal "authentication.security_event", event.fetch("event")
    assert_equal "rate_limit.exceeded", data.fetch("event_type")
    assert_equal "warning", data.fetch("severity")
    assert_equal "telephone_verification_rate_limit", data.fetch("reason_code")
    assert_equal "[FILTERED]", data.fetch("token")
    assert_equal "[FILTERED]", data.fetch("verifier")
    assert_equal "[FILTERED]", data.fetch("challenge")
    assert_equal "[FILTERED]", data.fetch("totp_secret")
    assert_equal "[FILTERED]", data.fetch("recovery_secret")
    assert_equal "[FILTERED]", data.fetch("cookie")
  end

  test "rejects unknown event types" do
    assert_raises(ArgumentError) do
      AuthenticationSecurityEventEmitter.emit("not.real")
    end
  end
end
