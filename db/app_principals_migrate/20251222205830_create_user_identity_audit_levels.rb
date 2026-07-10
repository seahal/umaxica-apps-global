# frozen_string_literal: true

class CreateUserIdentityAuditLevels < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_identity_audit_levels, id: :string) do |t|
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute("ALTER TABLE user_identity_audit_levels ALTER COLUMN id SET DEFAULT 'NONE'")
      end
      dir.down do
        execute("ALTER TABLE user_identity_audit_levels ALTER COLUMN id DROP DEFAULT")
      end
    end
  end
end
