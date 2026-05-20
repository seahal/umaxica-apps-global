# frozen_string_literal: true

class RenameUserPasskeyStatusIdToStatusId < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      rename_status_column(
        table: :user_passkeys,
        status_table: :user_passkey_statuses,
        old_column: :user_passkey_status_id,
        new_column: :status_id,
        old_index_name: "index_user_passkeys_on_user_passkey_status_id",
        new_index_name: "index_user_passkeys_on_status_id",
      )
    end
  end

  def down
    safety_assured do
      rename_status_column(
        table: :user_passkeys,
        status_table: :user_passkey_statuses,
        old_column: :status_id,
        new_column: :user_passkey_status_id,
        old_index_name: "index_user_passkeys_on_status_id",
        new_index_name: "index_user_passkeys_on_user_passkey_status_id",
      )
    end
  end

  private

  def rename_status_column(table:, status_table:, old_column:, new_column:, old_index_name:, new_index_name:)
    return unless table_exists?(table)
    return unless connection.column_exists?(table, old_column)
    return if connection.column_exists?(table, new_column)

    remove_foreign_key(table, status_table, column: old_column, if_exists: true)
    rename_column(table, old_column, new_column)

    if index_name_exists?(table, old_index_name)
      rename_index(table, old_index_name, new_index_name)
    elsif !index_exists?(table, new_column)
      add_index(table, new_column, name: new_index_name, algorithm: :concurrently)
    end

    return if foreign_key_exists?(table, status_table, column: new_column)

    add_foreign_key(table, status_table, column: new_column, validate: false)

  end
end
