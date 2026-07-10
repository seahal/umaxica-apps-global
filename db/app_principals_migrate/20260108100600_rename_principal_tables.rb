# frozen_string_literal: true

class RenamePrincipalTables < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      rename_table(:user_identity_emails, :user_emails)
      rename_table(:user_identity_telephones, :user_telephones)
      rename_table(:user_identity_secrets, :user_secrets)
      rename_table(:user_identity_statuses, :user_statuses)
      rename_table(:user_identity_one_time_passwords, :user_one_time_passwords)
      rename_table(:user_identity_social_apples, :user_social_apples)
      rename_table(:user_identity_social_googles, :user_social_googles)

      rename_table(:user_identity_email_statuses, :user_email_statuses)
      rename_table(:user_identity_telephone_statuses, :user_telephone_statuses)
      rename_table(:user_identity_secret_statuses, :user_secret_statuses)
      rename_table(:user_identity_passkey_statuses, :user_passkey_statuses)
      rename_table(:user_identity_one_time_password_statuses, :user_one_time_password_statuses)
      rename_table(:user_identity_social_apple_statuses, :user_social_apple_statuses)
      rename_table(:user_identity_social_google_statuses, :user_social_google_statuses)

      rename_table(:client_identity_statuses, :client_statuses)
    end
  end
end
