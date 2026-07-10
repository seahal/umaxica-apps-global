# frozen_string_literal: true

class RenameUserStatusIdToUserIdentityStatusId < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    return unless column_exists?(:users, :user_status_id)

    # Remove existing foreign key if present
    if foreign_key_exists?(:users, column: :user_status_id)
      remove_foreign_key(:users, column: :user_status_id)
    end

    # Rename column
    rename_column(:users, :user_status_id, :user_identity_status_id)

    # Recreate index with new name
    if index_exists?(:users, :user_identity_status_id, name: 'index_users_on_user_status_id')
      remove_index(:users, name: 'index_users_on_user_status_id')
    elsif index_exists?(:users, :user_status_id)
      remove_index(:users, :user_status_id)
    end

    add_index(:users, :user_identity_status_id, name: 'index_users_on_user_identity_status_id') unless index_exists?(
      :users, :user_identity_status_id, name: 'index_users_on_user_identity_status_id',
    )

    # Add foreign key pointing to user_identity_statuses.id
    add_foreign_key(:users, :user_identity_statuses, column: :user_identity_status_id, primary_key: :id)
  end

  def down
    return unless column_exists?(:users, :user_identity_status_id)

    remove_foreign_key(:users, column: :user_identity_status_id) if foreign_key_exists?(
      :users,
      column: :user_identity_status_id,
    )

    remove_index(:users, name: 'index_users_on_user_identity_status_id') if index_exists?(
      :users,
      :user_identity_status_id,
    )

    rename_column(:users, :user_identity_status_id, :user_status_id)

    add_index(:users, :user_status_id, name: 'index_users_on_user_status_id')
    add_foreign_key(:users, :user_identity_statuses, column: :user_status_id, primary_key: :id)
  end
end
