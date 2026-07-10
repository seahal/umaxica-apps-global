# frozen_string_literal: true

class FixPrincipalPasskeyTables < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # Fix User Passkeys
      if connection.table_exists?(:user_passkeys) && connection.column_exists?(:user_passkeys, :external_id)
        # This is the collision table (wrong schema)
        drop_table(:user_passkeys)
      end

      if connection.table_exists?(:user_identity_passkeys) && !connection.table_exists?(:user_passkeys)
        connection.execute("ALTER TABLE user_identity_passkeys RENAME TO user_passkeys")
      end

      # Rename columns on the newly established user_passkeys table
      if connection.table_exists?(:user_passkeys) && connection.column_exists?(
        :user_passkeys,
        :user_identity_passkey_status_id,
      )
        rename_column(:user_passkeys, :user_identity_passkey_status_id, :user_passkey_status_id)
      end
    end
  end

  def down
  end
end
