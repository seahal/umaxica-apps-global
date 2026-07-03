# typed: false
# frozen_string_literal: true

class ClientProcessorErasureNotification < AppPrincipalRecord
  include ProcessorErasureNotificationState

  STATUS_MODEL = ClientProcessorErasureNotificationStatus
  STATUSES = {
    "PENDING" => STATUS_MODEL::PENDING,
    "NOTIFIED" => STATUS_MODEL::NOTIFIED,
    "FAILED" => STATUS_MODEL::FAILED,
    "SKIPPED" => STATUS_MODEL::SKIPPED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :client_privacy_request, inverse_of: :client_processor_erasure_notifications
  belongs_to :status, class_name: "ClientProcessorErasureNotificationStatus", foreign_key: :status_id
end
