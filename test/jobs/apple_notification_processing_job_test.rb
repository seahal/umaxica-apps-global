# frozen_string_literal: true

require "test_helper"

class AppleNotificationProcessingJobTest < ActiveJob::TestCase
  test "re-enqueues a processing failure within the bounded retry window" do
    event = ClientAppleNotificationEvent.create!(
      jti: "retry-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      received_at: Time.current,
      occurred_at: Time.current,
    )

    ExternalAuthenticationAppleNotificationProcessor.stub(
      :call,
      ->(**) { raise StandardError, "processing failed" },
    ) do
      assert_enqueued_with(job: AppleNotificationProcessingJob, args: [event.jti]) do
        AppleNotificationProcessingJob.perform_now(event.jti)
      end
    end

    assert_equal "retrying", event.reload.status
    assert_equal 1, event.processing_attempts
    assert_equal "processor_failure", event.failure_code
  end

  test "dead-letters an exhausted notification and alerts operations" do
    event = ClientAppleNotificationEvent.create!(
      jti: "dead-letter-#{SecureRandom.hex(8)}",
      event_type: "consent-revoked",
      received_at: Time.current,
      occurred_at: Time.current,
      processing_attempts: ClientAppleNotificationEvent::MAXIMUM_ATTEMPTS - 1,
    )
    alerted = []

    ExternalAuthenticationAppleNotificationProcessor.stub(
      :call,
      ->(**) { raise StandardError, "processing failed" },
    ) do
      ExternalAuthenticationAppleNotificationDeadLetterAlert.stub(:call, ->(**attributes) { alerted << attributes }) do
        AppleNotificationProcessingJob.perform_now(event.jti)
      end
    end

    assert_equal "dead_letter", event.reload.status
    assert_equal [{ event: event }], alerted
  end
end
