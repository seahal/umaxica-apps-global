# frozen_string_literal: true

class RenameStaffIdentityAuditStatusToEvent < ActiveRecord::Migration[8.2]
  def change
    rename_table(:staff_identity_audit_statuses, :staff_identity_audit_events)
    rename_column(:staff_identity_audits, :status_id, :event_id)
  end
end
