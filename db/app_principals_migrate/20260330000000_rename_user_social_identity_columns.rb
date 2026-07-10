# frozen_string_literal: true

class RenameUserSocialIdentityColumns < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      rename_social_columns(
        table: :user_social_apples,
        expires_from: :expires_at,
        status_from: :user_identity_social_apple_status_id,
      )
      rename_social_columns(
        table: :user_social_googles,
        expires_from: :expires_at,
        status_from: :user_identity_social_google_status_id,
      )
    end
  end

  def down
    safety_assured do
      rename_social_columns(
        table: :user_social_apples,
        expires_from: :token_expires_at,
        status_from: :status_id,
        expires_to: :expires_at,
        status_to: :user_identity_social_apple_status_id,
      )
      rename_social_columns(
        table: :user_social_googles,
        expires_from: :token_expires_at,
        status_from: :status_id,
        expires_to: :expires_at,
        status_to: :user_identity_social_google_status_id,
      )
    end
  end

  private

  def rename_social_columns(table:, expires_from:, status_from:, expires_to: :token_expires_at, status_to: :status_id)
    return unless table_exists?(table)

    safe_rename_column(table, expires_from, expires_to)
    safe_rename_column(table, status_from, status_to)
  end

  def safe_rename_column(table, old_col, new_col)
    return unless connection.column_exists?(table, old_col)
    return if connection.column_exists?(table, new_col)

    rename_column(table, old_col, new_col)
  end
end
