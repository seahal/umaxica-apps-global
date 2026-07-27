# frozen_string_literal: true

# adr/unified-enforcement.md, Audit contract. Lifecycle events for Unified
# Enforcement Cases. Keyed on case_public_id and principal_public_id strings
# (never bigints) -- deliberately not repeating account_access_events' existing
# adr/cross-db-reference-policy.md violation (account_id :bigint).
class CreateEnforcementEvents < ActiveRecord::Migration[8.2]
  def change
    create_table(:enforcement_events) do |t|
      t.string(:realm, null: false)
      t.string(:case_public_id, null: false)
      t.string(:principal_public_id, null: false)
      t.string(:event_type, null: false)
      t.string(:reason_code)
      t.string(:operator_public_id)
      t.boolean(:break_glass, null: false, default: false)
      t.string(:ticket_id)
      t.datetime(:occurred_at, null: false)
      t.jsonb(:metadata, null: false, default: {})

      t.timestamps
    end

    add_index(:enforcement_events, %i(realm case_public_id occurred_at), name: "idx_enforcement_events_case")
    add_index(:enforcement_events, %i(realm principal_public_id occurred_at), name: "idx_enforcement_events_principal")
    add_index(:enforcement_events, :event_type)

    add_check_constraint(
      :enforcement_events,
      "realm IN ('app', 'com', 'org')",
      name: "chk_enforcement_events_realm",
    )
    add_check_constraint(
      :enforcement_events,
      "event_type IN (" \
      "'created', 'approval_requested', 'approved', 'applied', 'activated', 'extended', " \
      "'escalated', 'reduced', 'ended', 'expired', 'corrected', 'break_glass_released', " \
      "'appeal_submitted', 'appeal_approved', 'appeal_rejected', " \
      "'principal_linked', 'principal_reinstated', " \
      "'revocation_failed', 'revocation_reconciled')",
      name: "chk_enforcement_events_event_type",
    )
  end
end
