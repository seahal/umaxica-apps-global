# frozen_string_literal: true

class DropLegacyUserIdentityAuditTables < ActiveRecord::Migration[8.2]
  def up
    drop_table(:user_identity_audits, if_exists: true)
    drop_table(:user_identity_audit_events, if_exists: true)
    drop_table(:user_identity_audit_levels, if_exists: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Dropped legacy user_identity_audit_* tables"
  end
end
