# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationJob < ApplicationJob
  queue_as :retention

  SUPPORTED_PROCESSORS = %w(
    email_delivery
    sms_delivery
    push_delivery
    analytics
    object_storage
    search_index
    log_pipeline
  ).freeze

  def perform(surface:, public_id:)
    notification = notification_class_for(surface).find_by!(public_id: public_id)
    return if notification.terminal?

    subject = subject_for(notification)
    WithdrawalOccurrenceRecording.record!(
      subject: subject,
      event_type: "processor_erasure.notification_requested",
      context: occurrence_context(notification),
    )

    if SUPPORTED_PROCESSORS.include?(notification.processor_key)
      notification.mark_notified!
      WithdrawalOccurrenceRecording.record!(
        subject: subject,
        event_type: "processor_erasure.notified",
        context: occurrence_context(notification),
      )
    else
      notification.mark_failed!(code: "processor_unavailable", message: "Processor integration is not configured")
      WithdrawalOccurrenceRecording.record!(
        subject: subject,
        event_type: "processor_erasure.failed",
        context: occurrence_context(notification).merge(reason_code: "processor_unavailable"),
      )
    end
  end

  private

  def notification_class_for(surface)
    case surface.to_s
    when "app" then ClientProcessorErasureNotification
    when "com" then VisitorProcessorErasureNotification
    else
      raise ArgumentError, "unsupported processor erasure surface: #{surface.inspect}"
    end
  end

  def subject_for(notification)
    case notification
    when ClientProcessorErasureNotification then notification.client_privacy_request.client
    when VisitorProcessorErasureNotification then notification.visitor_privacy_request.visitor
    else
      raise ArgumentError, "unsupported processor notification: #{notification.class.name}"
    end
  end

  def privacy_request_for(notification)
    case notification
    when ClientProcessorErasureNotification then notification.client_privacy_request
    when VisitorProcessorErasureNotification then notification.visitor_privacy_request
    else
      raise ArgumentError, "unsupported processor notification: #{notification.class.name}"
    end
  end

  def occurrence_context(notification)
    {
      processor_key: notification.processor_key,
      processor_notification_public_id: notification.public_id,
      privacy_request_public_id: privacy_request_for(notification).public_id,
    }
  end
end
