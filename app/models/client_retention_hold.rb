# typed: false
# frozen_string_literal: true

class ClientRetentionHold < AppPrincipalRecord
  include RetentionHoldState

  STATUS_MODEL = ClientRetentionHoldStatus
  STATUSES = {
    "ACTIVE" => STATUS_MODEL::ACTIVE,
    "RELEASED" => STATUS_MODEL::RELEASED,
    "EXPIRED" => STATUS_MODEL::EXPIRED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze

  belongs_to :client, inverse_of: :client_retention_holds
  belongs_to :status, class_name: "ClientRetentionHoldStatus", foreign_key: :status_id
end
