# frozen_string_literal: true

class AddForeignKeysToStaffAuditTables < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(:staff_identity_audits, :staff_identity_audit_events, column: :event_id)
  end
end
