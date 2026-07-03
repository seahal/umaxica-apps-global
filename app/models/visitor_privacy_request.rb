# typed: false
# frozen_string_literal: true

class VisitorPrivacyRequest < ComPrincipalRecord
  include PrivacyRequestState

  STATUS_MODEL = VisitorPrivacyRequestStatus
  STATUSES = {
    "RECEIVED" => STATUS_MODEL::RECEIVED,
    "VERIFICATION_REQUIRED" => STATUS_MODEL::VERIFICATION_REQUIRED,
    "VERIFIED" => STATUS_MODEL::VERIFIED,
    "PROCESSING" => STATUS_MODEL::PROCESSING,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
    "PARTIALLY_DENIED" => STATUS_MODEL::PARTIALLY_DENIED,
    "BLOCKED_BY_LEGAL_HOLD" => STATUS_MODEL::BLOCKED_BY_LEGAL_HOLD,
    "CANCELLED" => STATUS_MODEL::CANCELLED,
    "FAILED" => STATUS_MODEL::FAILED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :visitor, inverse_of: :visitor_privacy_requests
  belongs_to :status, class_name: "VisitorPrivacyRequestStatus", foreign_key: :status_id
  has_many :visitor_processor_erasure_notifications, dependent: :delete_all, inverse_of: :visitor_privacy_request
end
