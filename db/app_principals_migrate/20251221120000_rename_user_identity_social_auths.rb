# frozen_string_literal: true

class RenameUserIdentitySocialAuths < ActiveRecord::Migration[8.2]
  def up
    if table_exists?(:user_apple_auths) && !table_exists?(:user_identity_social_apples)
      rename_table(:user_apple_auths, :user_identity_social_apples)
    end

    if table_exists?(:user_google_auths) && !table_exists?(:user_identity_social_googles)
      rename_table(:user_google_auths, :user_identity_social_googles)
    end

    if table_exists?(:user_identity_apple_auth_statuses) && !table_exists?(:user_identity_social_apple_statuses)
      rename_table(:user_identity_apple_auth_statuses, :user_identity_social_apple_statuses)
    end

    if table_exists?(:user_identity_google_auth_statuses) && !table_exists?(:user_identity_social_google_statuses)
      rename_table(:user_identity_google_auth_statuses, :user_identity_social_google_statuses)
    end

    if column_exists?(:user_identity_social_apples, :user_identity_apple_auth_status_id)
      rename_column(
        :user_identity_social_apples,
        :user_identity_apple_auth_status_id,
        :user_identity_social_apple_status_id,
      )
    end

    if column_exists?(:user_identity_social_googles, :user_identity_google_auth_status_id)
      rename_column(
        :user_identity_social_googles,
        :user_identity_google_auth_status_id,
        :user_identity_social_google_status_id,
      )
    end

    rename_social_indexes(
      :user_identity_social_apples,
      old_table: :user_apple_auths,
      old_status_column: :user_identity_apple_auth_status_id,
      new_status_column: :user_identity_social_apple_status_id,
    )
    rename_social_indexes(
      :user_identity_social_googles,
      old_table: :user_google_auths,
      old_status_column: :user_identity_google_auth_status_id,
      new_status_column: :user_identity_social_google_status_id,
    )
  end

  def down
    rename_social_indexes(
      :user_identity_social_apples,
      old_table: :user_identity_social_apples,
      new_table: :user_apple_auths,
      old_status_column: :user_identity_social_apple_status_id,
      new_status_column: :user_identity_apple_auth_status_id,
    )
    rename_social_indexes(
      :user_identity_social_googles,
      old_table: :user_identity_social_googles,
      new_table: :user_google_auths,
      old_status_column: :user_identity_social_google_status_id,
      new_status_column: :user_identity_google_auth_status_id,
    )

    if column_exists?(:user_identity_social_apples, :user_identity_social_apple_status_id)
      rename_column(
        :user_identity_social_apples,
        :user_identity_social_apple_status_id,
        :user_identity_apple_auth_status_id,
      )
    end

    if column_exists?(:user_identity_social_googles, :user_identity_social_google_status_id)
      rename_column(
        :user_identity_social_googles,
        :user_identity_social_google_status_id,
        :user_identity_google_auth_status_id,
      )
    end

    if table_exists?(:user_identity_social_apple_statuses) && !table_exists?(:user_identity_apple_auth_statuses)
      rename_table(:user_identity_social_apple_statuses, :user_identity_apple_auth_statuses)
    end

    if table_exists?(:user_identity_social_google_statuses) && !table_exists?(:user_identity_google_auth_statuses)
      rename_table(:user_identity_social_google_statuses, :user_identity_google_auth_statuses)
    end

    if table_exists?(:user_identity_social_apples) && !table_exists?(:user_apple_auths)
      rename_table(:user_identity_social_apples, :user_apple_auths)
    end

    return unless table_exists?(:user_identity_social_googles) && !table_exists?(:user_google_auths)

    rename_table(:user_identity_social_googles, :user_google_auths)

  end

  private

  def rename_social_indexes(table, old_table:, old_status_column:, new_status_column:, new_table: nil)
    new_table ||= table

    uid_provider_old = "index_#{old_table}_on_uid_and_provider"
    uid_provider_new = "index_#{new_table}_on_uid_and_provider"
    rename_index(table, uid_provider_old, uid_provider_new) if index_exists?(table, name: uid_provider_old)

    user_id_unique_old = "index_#{old_table}_on_user_id_unique"
    user_id_unique_new = "index_#{new_table}_on_user_id_unique"
    rename_index(table, user_id_unique_old, user_id_unique_new) if index_exists?(table, name: user_id_unique_old)

    user_id_old = "index_#{old_table}_on_user_id"
    user_id_new = "index_#{new_table}_on_user_id"
    rename_index(table, user_id_old, user_id_new) if index_exists?(table, name: user_id_old)

    status_old = "index_#{old_table}_on_#{old_status_column}"
    status_new = "index_#{new_table}_on_#{new_status_column}"
    rename_index(table, status_old, status_new) if index_exists?(table, name: status_old)
  end
end
