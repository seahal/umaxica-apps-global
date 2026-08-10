# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleNotificationDeadLetterAlertTest < ActiveSupport::TestCase
  test "requires a ClientAppleNotificationEvent" do
    assert_raises(ArgumentError) do
      ExternalAuthenticationAppleNotificationDeadLetterAlert.new(event: Object.new)
    end
  end

  test "reports a handled dead-letter error with notification identifiers" do
    event = ClientAppleNotificationEvent.new(
      jti: "jti-#{SecureRandom.hex(4)}",
      event_type: "consent-revoked",
      status: "dead_letter",
      processing_attempts: 10,
      received_at: Time.utc(2026, 8, 1, 0, 0, 0),
      occurred_at: Time.utc(2026, 8, 1, 0, 0, 0),
    )

    reported = nil
    reporter =
      lambda { |error, handled:, context:|
        reported = { error: error, handled: handled, context: context }
      }

    Rails.error.stub(:report, reporter) do
      ExternalAuthenticationAppleNotificationDeadLetterAlert.call(event: event)
    end

    assert reported[:handled]
    assert_instance_of ExternalAuthenticationAppleNotificationDeadLetterAlert::Error, reported[:error]
    assert_equal "apple", reported[:context][:provider]
    assert_equal "consent-revoked", reported[:context][:notification_event_type]
    assert_equal event.jti, reported[:context][:notification_jti]
    assert_equal 10, reported[:context][:processing_attempts]
  end
end
