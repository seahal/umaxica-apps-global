# frozen_string_literal: true

class ChangeUserIdToUuidInOtherTables < ActiveRecord::Migration[8.2]
  def up
    # Change user_id in user_google_auths
    change_user_id_type(:user_google_auths)

    # Change user_id in user_apple_auths
    change_user_id_type(:user_apple_auths)

    # Change user_id in user_identity_telephones
    change_user_id_type(:user_identity_telephones)

    # Change user_id in user_recovery_codes
    change_user_id_type(:user_recovery_codes)
  end

  def down
    # Revert user_id in user_google_auths
    revert_user_id_type(:user_google_auths)

    # Revert user_id in user_apple_auths
    revert_user_id_type(:user_apple_auths)

    # Revert user_id in user_identity_telephones
    revert_user_id_type(:user_identity_telephones)

    # Revert user_id in user_recovery_codes
    revert_user_id_type(:user_recovery_codes)
  end

  private

  def change_user_id_type(table_name)
    return unless table_exists?(table_name)

    # Remove the index first
    remove_index(table_name, :user_id) if index_exists?(table_name, :user_id)

    # Remove the foreign key if it exists
    remove_foreign_key(table_name, :users) if foreign_key_exists?(table_name, :users)

    # Remove the old column and add it back as uuid
    # Warning: This will lose existing data in the user_id column
    remove_column(table_name, :user_id, :bigint)
    add_column(table_name, :user_id, :bigint)

    # Add the index back
    add_index(table_name, :user_id)

    # Add foreign key constraint when types match
    return unless compatible_foreign_key_type?(table_name, :user_id, :users)

    add_foreign_key(table_name, :users)

  end

  def revert_user_id_type(table_name)
    return unless table_exists?(table_name)

    # Remove the index first
    remove_index(table_name, :user_id) if index_exists?(table_name, :user_id)

    # Remove the foreign key
    remove_foreign_key(table_name, :users) if foreign_key_exists?(table_name, :users)

    # Remove the uuid column and add back as bigint
    remove_column(table_name, :user_id, :uuid)
    add_column(table_name, :user_id, :bigint)

    # Add the index back
    add_index(table_name, :user_id)

    # Add foreign key constraint when types match
    return unless compatible_foreign_key_type?(table_name, :user_id, :users)

    add_foreign_key(table_name, :users)

  end

  def compatible_foreign_key_type?(from_table, from_column, to_table)
    return false unless table_exists?(from_table) && table_exists?(to_table)

    from_type = column_type(from_table, from_column)
    to_type = column_type(to_table, :id)
    from_type && to_type && from_type == to_type
  end

  def column_type(table_name, column_name)
    connection.columns(table_name).find { |column| column.name == column_name.to_s }&.type
  end
end
