# frozen_string_literal: true

class CreateAccountAccessEvents < ActiveRecord::Migration[8.2]
  def change
    create_table(:account_access_events) do |t|
      t.string(:account_type, null: false)
      t.bigint(:account_id, null: false)
      t.string(:event_type, null: false)
      t.string(:previous_access_state, null: false)
      t.string(:next_access_state, null: false)
      t.bigint(:operator_id, null: false)
      t.string(:reason_code, null: false)
      t.text(:reason_note)
      t.string(:ticket_id)
      t.datetime(:occurred_at, null: false)
      t.jsonb(:metadata, null: false, default: {})

      t.timestamps
    end

    add_index(:account_access_events, %i(account_type account_id occurred_at))
    add_index(:account_access_events, :operator_id)
    add_index(:account_access_events, :event_type)
    add_index(:account_access_events, :reason_code)
    add_index(:account_access_events, :ticket_id)

    add_check_constraint(
      :account_access_events,
      "account_type IN ('Client', 'Visitor', 'Operator')",
      name: "chk_account_access_events_account_type",
    )
    add_check_constraint(
      :account_access_events,
      "event_type IN ('admin_lock', 'admin_lock_reaffirmed', 'admin_unlock')",
      name: "chk_account_access_events_event_type",
    )
    add_check_constraint(
      :account_access_events,
      "previous_access_state IN ('enabled', 'admin_locked')",
      name: "chk_account_access_events_previous_access_state",
    )
    add_check_constraint(
      :account_access_events,
      "next_access_state IN ('enabled', 'admin_locked')",
      name: "chk_account_access_events_next_access_state",
    )
    add_check_constraint(
      :account_access_events,
      "reason_code IN ('abuse', 'security_incident', 'chargeback', " \
      "'terms_violation', 'support_request', 'legal_hold', " \
      "'operator_error_recovery', 'other')",
      name: "chk_account_access_events_reason_code",
    )
  end
end
