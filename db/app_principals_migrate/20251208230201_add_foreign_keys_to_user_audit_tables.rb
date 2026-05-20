# frozen_string_literal: true

class AddForeignKeysToUserAuditTables < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(:user_identity_audits, :user_identity_audit_events, column: :event_id)
  end
end
