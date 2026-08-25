# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Audit contract. Immutable lifecycle history for
# Unified Enforcement Cases across all three realms. Denial events (high
# volume, attacker-driven) do not live here -- they are occurrence counters
# (adr/unified-enforcement.md, Audit contract).
class EnforcementEvent < ChronicleRecord
  REALMS = %w(app com org).freeze

  EVENT_TYPES = %w(
    created approval_requested approved applied activated extended
    escalated reduced ended expired corrected break_glass_released
    appeal_submitted appeal_approved appeal_rejected
    principal_linked principal_reinstated
    revocation_failed revocation_reconciled
  ).freeze

  validates :realm, presence: true, inclusion: { in: REALMS }
  validates :case_public_id, presence: true
  validates :principal_public_id, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validates :metadata, exclusion: { in: [nil] }
end
