# typed: false
# frozen_string_literal: true

class VisitorRetentionHold < ComPrincipalRecord
  include RetentionHoldState

  STATUS_MODEL = VisitorRetentionHoldStatus
  STATUSES = {
    "ACTIVE" => STATUS_MODEL::ACTIVE,
    "RELEASED" => STATUS_MODEL::RELEASED,
    "EXPIRED" => STATUS_MODEL::EXPIRED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :visitor, inverse_of: :visitor_retention_holds
  belongs_to :status, class_name: "VisitorRetentionHoldStatus", foreign_key: :status_id
end
