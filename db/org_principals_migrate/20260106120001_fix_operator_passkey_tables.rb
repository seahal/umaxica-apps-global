# frozen_string_literal: true

class FixOperatorPasskeyTables < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # Fix Staff Passkeys
      if connection.table_exists?(:staff_passkeys) && connection.column_exists?(:staff_passkeys, :external_id)
        # Collision table
        drop_table(:staff_passkeys)
      end

      if connection.table_exists?(:staff_identity_passkeys) && !connection.table_exists?(:staff_passkeys)
        connection.execute("ALTER TABLE staff_identity_passkeys RENAME TO staff_passkeys")
      end

      # Rename columns
      if connection.table_exists?(:staff_passkeys) && connection.column_exists?(
        :staff_passkeys,
        :staff_identity_passkey_status_id,
      )
        rename_column(:staff_passkeys, :staff_identity_passkey_status_id, :staff_passkey_status_id)
      end
    end
  end

  def down
  end
end
