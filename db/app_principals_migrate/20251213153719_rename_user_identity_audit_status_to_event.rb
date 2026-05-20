# frozen_string_literal: true

class RenameUserIdentityAuditStatusToEvent < ActiveRecord::Migration[8.2]
  def change
    rename_table(:user_identity_audit_statuses, :user_identity_audit_events)
    rename_column(:user_identity_audits, :status_id, :event_id)
  end
end
