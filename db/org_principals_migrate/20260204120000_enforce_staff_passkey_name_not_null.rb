# frozen_string_literal: true

class EnforceStaffPasskeyNameNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      return unless table_exists?(:staff_passkeys)
      return unless column_exists?(:staff_passkeys, :name)

      execute("UPDATE staff_passkeys SET name = 'passkey' WHERE name IS NULL")
      execute("ALTER TABLE staff_passkeys ALTER COLUMN name SET NOT NULL")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
