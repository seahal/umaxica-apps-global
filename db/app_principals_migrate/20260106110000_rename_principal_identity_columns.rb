# frozen_string_literal: true

class RenamePrincipalIdentityColumns < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      safe_rename_column(:user_emails, :user_identity_email_status_id, :user_email_status_id)
      safe_rename_column(:user_passkeys, :user_identity_passkey_status_id, :user_passkey_status_id)
      safe_rename_column(:user_secrets, :user_identity_secret_status_id, :user_secret_status_id)
      safe_rename_column(:user_social_apples, :user_identity_social_apple_status_id, :user_social_apple_status_id)
      safe_rename_column(:user_social_googles, :user_identity_social_google_status_id, :user_social_google_status_id)
      safe_rename_column(:user_telephones, :user_identity_telephone_status_id, :user_telephone_status_id)
      safe_rename_column(
        :user_one_time_passwords, :user_identity_one_time_password_status_id,
        :user_one_time_password_status_id,
      )
    end
  end

  def down
    safety_assured do
      safe_rename_column(:user_emails, :user_email_status_id, :user_identity_email_status_id)
      safe_rename_column(:user_passkeys, :user_passkey_status_id, :user_identity_passkey_status_id)
      safe_rename_column(:user_secrets, :user_secret_status_id, :user_identity_secret_status_id)
      safe_rename_column(:user_social_apples, :user_social_apple_status_id, :user_identity_social_apple_status_id)
      safe_rename_column(:user_social_googles, :user_social_google_status_id, :user_identity_social_google_status_id)
      safe_rename_column(:user_telephones, :user_telephone_status_id, :user_identity_telephone_status_id)
      safe_rename_column(
        :user_one_time_passwords, :user_one_time_password_status_id,
        :user_identity_one_time_password_status_id,
      )
    end
  end

  private

  def safe_rename_column(table, old_col, new_col)
    return unless table_exists?(table)
    return unless connection.column_exists?(table, old_col)
    return if connection.column_exists?(table, new_col)

    rename_column(table, old_col, new_col)
  end
end
