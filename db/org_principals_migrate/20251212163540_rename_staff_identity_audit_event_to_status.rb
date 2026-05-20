# frozen_string_literal: true

class RenameStaffIdentityAuditEventToStatus < ActiveRecord::Migration[8.2]
  def change
    rename_table(:staff_identity_audit_events, :staff_identity_audit_statuses)
    rename_column(:staff_identity_audits, :event_id, :status_id)
  end
end
