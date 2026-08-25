# typed: false
# frozen_string_literal: true

class ExternalAuthenticationAppleNotificationDeadLetterAlert
  class Error < StandardError; end

  def self.call(event:)
    new(event:).call
  end

  def initialize(event:)
    raise ArgumentError, "event is required" unless event.is_a?(ClientAppleNotificationEvent)

    @event = event
  end

  def call
    Rails.error.report(
      Error.new("apple notification processing reached dead letter"),
      handled: true,
      context: {
        provider: "apple",
        notification_event_type: event.event_type,
        notification_jti: event.jti,
        processing_attempts: event.processing_attempts,
      },
    )
  end

  private

  attr_reader :event
end
