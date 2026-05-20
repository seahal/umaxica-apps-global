# frozen_string_literal: true

class ChangeUserIdToUuidInUserIdentityEmails < ActiveRecord::Migration[8.2]
  def up
    # Remove the index first
    remove_index(:user_identity_emails, :user_id) if index_exists?(:user_identity_emails, :user_id)

    # Remove the foreign key if it exists
    remove_foreign_key(:user_identity_emails, :users) if foreign_key_exists?(:user_identity_emails, :users)

    # Remove the old column and add it back as uuid
    # Warning: This will lose existing data in the user_id column
    change_table(:user_identity_emails, bulk: true) do |t|
      t.remove(:user_id)
      t.bigint(:user_id)
    end

    # Add the index back
    add_index(:user_identity_emails, :user_id)

    # Add foreign key constraint when types match
    return unless compatible_foreign_key_type?(:user_identity_emails, :user_id, :users)

    add_foreign_key(:user_identity_emails, :users)

  end

  def down
    # Remove the index first
    remove_index(:user_identity_emails, :user_id) if index_exists?(:user_identity_emails, :user_id)

    # Remove the foreign key
    remove_foreign_key(:user_identity_emails, :users) if foreign_key_exists?(:user_identity_emails, :users)

    # Remove the uuid column and add back as bigint
    change_table(:user_identity_emails, bulk: true) do |t|
      t.remove(:user_id)
      t.bigint(:user_id)
    end

    # Add the index back
    add_index(:user_identity_emails, :user_id)

    # Add foreign key constraint when types match
    return unless compatible_foreign_key_type?(:user_identity_emails, :user_id, :users)

    add_foreign_key(:user_identity_emails, :users)

  end

  private

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
