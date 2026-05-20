# frozen_string_literal: true

class AddMissingForeignKeyToUserIdentityAudits < ActiveRecord::Migration[8.2]
  def change
    return if foreign_key_exists?(:user_identity_audits, column: :event_id)

    add_foreign_key(:user_identity_audits, :user_identity_audit_events, column: :event_id)

  end
end
