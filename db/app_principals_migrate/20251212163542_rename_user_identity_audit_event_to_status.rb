# frozen_string_literal: true

class RenameUserIdentityAuditEventToStatus < ActiveRecord::Migration[8.2]
  def change
    rename_table(:user_identity_audit_events, :user_identity_audit_statuses)
    rename_column(:user_identity_audits, :event_id, :status_id)
  end
end
