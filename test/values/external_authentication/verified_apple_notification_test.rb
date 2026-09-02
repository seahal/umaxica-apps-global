# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationVerifiedAppleNotificationTest < ActiveSupport::TestCase
  test "rejects missing identifiers unsupported event types and non-time stamps" do
    now = Time.utc(2026, 7, 24, 12, 0, 0)

    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedAppleNotification.new(
        jti: "", event_type: "consent-revoked", subject: "sub", issued_at: now, occurred_at: now,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedAppleNotification.new(
        jti: "jti", event_type: "unknown", subject: "sub", issued_at: now, occurred_at: now,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedAppleNotification.new(
        jti: "jti", event_type: "consent-revoked", subject: "", issued_at: now, occurred_at: now,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedAppleNotification.new(
        jti: "jti", event_type: "consent-revoked", subject: "sub", issued_at: "now", occurred_at: now,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::VerifiedAppleNotification.new(
        jti: "jti", event_type: "consent-revoked", subject: "sub", issued_at: now, occurred_at: "now",
      )
    end
  end
end
