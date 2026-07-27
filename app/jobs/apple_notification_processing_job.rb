# typed: false
# frozen_string_literal: true

class AppleNotificationProcessingJob < ApplicationJob
  queue_as :default

  def perform(jti)
    event = ClientAppleNotificationEvent.lock.find_by!(jti: jti)
    return if event.terminal?

    ExternalAuthenticationAppleNotificationProcessor.call(event: event)
  rescue StandardError
    raise unless defined?(event) && event

    outcome = event.retry_or_dead_letter!(code: "processor_failure")
    if outcome == :retrying
      self.class.set(wait_until: event.next_retry_at).perform_later(event.jti)
    else
      ExternalAuthenticationAppleNotificationDeadLetterAlert.call(event: event)
    end
  end
end
