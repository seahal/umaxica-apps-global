# typed: false
# frozen_string_literal: true

class AccountAccessEvent < ChronicleRecord
  EVENT_TYPE_ADMIN_LOCK = "admin_lock"
  EVENT_TYPE_ADMIN_LOCK_REAFFIRMED = "admin_lock_reaffirmed"
  EVENT_TYPE_ADMIN_UNLOCK = "admin_unlock"
  EVENT_TYPES = [
    EVENT_TYPE_ADMIN_LOCK,
    EVENT_TYPE_ADMIN_LOCK_REAFFIRMED,
    EVENT_TYPE_ADMIN_UNLOCK,
  ].freeze

  ACCOUNT_TYPES = %w(Client Visitor Operator).freeze

  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :account_id, presence: true, numericality: { only_integer: true }
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :previous_access_state, presence: true, inclusion: { in: AdministrativeAccessLockable::ACCESS_STATES }
  validates :next_access_state, presence: true, inclusion: { in: AdministrativeAccessLockable::ACCESS_STATES }
  validates :operator_id, presence: true, numericality: { only_integer: true }
  validates :reason_code, presence: true, inclusion: { in: AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES }
  validates :metadata, exclusion: { in: [nil] }
end
