# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleNotificationIngressTest < ActiveJob::TestCase
  class FakeVerifier
    def initialize(notification)
      @notification = notification
    end

    def call
      @notification
    end
  end

  test "persists only the verified minimum event and enqueues processing" do
    notification = ExternalAuthentication::VerifiedAppleNotification.new(
      jti: "apple-notification-jti",
      event_type: "consent-revoked",
      subject: "apple-subject",
      issued_at: Time.utc(2026, 7, 24, 12, 0, 0),
      occurred_at: Time.utc(2026, 7, 24, 12, 0, 0),
    )

    assert_enqueued_with(job: AppleNotificationProcessingJob) do
      result = ExternalAuthenticationAppleNotificationIngress.call(
        jws: "signed-payload",
        verifier: FakeVerifier.new(notification),
      )

      assert_equal :accepted, result.status
    end

    event = ClientAppleNotificationEvent.find_by!(jti: "apple-notification-jti")

    assert_equal "consent-revoked", event.event_type
    assert_nil event.client_external_identity
    assert_not_includes event.attributes.values.map(&:to_s), "signed-payload"
  end

  test "treats a duplicate JTI as an idempotent no-op" do
    ClientAppleNotificationEvent.create!(
      jti: "duplicate-notification-jti",
      event_type: "email-enabled",
      received_at: Time.current,
      occurred_at: Time.current,
    )
    notification = ExternalAuthentication::VerifiedAppleNotification.new(
      jti: "duplicate-notification-jti",
      event_type: "email-enabled",
      subject: "apple-subject",
      issued_at: Time.current,
      occurred_at: Time.current,
    )

    assert_no_enqueued_jobs do
      result = ExternalAuthenticationAppleNotificationIngress.call(
        jws: "signed-payload",
        verifier: FakeVerifier.new(notification),
      )

      assert_equal :duplicate, result.status
    end

    assert_equal 1, ClientAppleNotificationEvent.where(jti: "duplicate-notification-jti").count
  end
end
