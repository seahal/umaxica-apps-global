# typed: false
# frozen_string_literal: true

class CspViolationSubscriber
  FAILURE_EVENT_NAME = "security.csp_violation.subscriber_failed"
  MAX_ERROR_MESSAGE_BYTES = 256

  def emit(event)
    Rails.logger.info(
      JitLogEvent.format(
        event.fetch(:name),
        event.fetch(:payload),
      ),
    )
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        FAILURE_EVENT_NAME,
        error_class: e.class.name,
        error_message: e.message.to_s.byteslice(0, MAX_ERROR_MESSAGE_BYTES),
      ),
    )
  end
end
