# typed: false
# frozen_string_literal: true

class VisitorProcessorErasureNotification < ComPrincipalRecord
  include ProcessorErasureNotificationState

  STATUS_MODEL = VisitorProcessorErasureNotificationStatus
  STATUSES = {
    "PENDING" => STATUS_MODEL::PENDING,
    "NOTIFIED" => STATUS_MODEL::NOTIFIED,
    "FAILED" => STATUS_MODEL::FAILED,
    "SKIPPED" => STATUS_MODEL::SKIPPED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :visitor_privacy_request, inverse_of: :visitor_processor_erasure_notifications
  belongs_to :status, class_name: "VisitorProcessorErasureNotificationStatus"
end
