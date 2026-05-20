# frozen_string_literal: true

class FixConsistencyUsers < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      tables = %w(
        users user_statuses user_telephones user_telephone_statuses
        user_emails user_email_statuses
        user_social_googles user_social_google_statuses
        user_social_apples user_social_apple_statuses
        user_secrets user_secret_statuses user_secret_kinds
        user_passkeys user_passkey_statuses
        user_one_time_passwords user_one_time_password_statuses
        clients client_statuses
      )
      tables.select! { |t| table_exists?(t) }
      # Delete in order (Children first) preventing FK violations
      %w(
        user_one_time_passwords user_passkeys user_secrets
        user_social_googles user_social_apples
        user_emails user_telephones
        clients
        users
        user_statuses user_telephone_statuses user_email_statuses
        user_social_google_statuses user_social_apple_statuses
        user_secret_statuses user_secret_kinds
        user_passkey_statuses
        user_one_time_password_statuses
        client_statuses
      ).each do |t|
        execute("DELETE FROM #{t}") if table_exists?(t)
      end

      # --- User ---
      remove_column(:users, :status_id) if column_exists?(:users, :status_id)
      add_reference(:users, :status, foreign_key: { to_table: :user_statuses }, type: :bigint, default: 0, null: false)

      # --- Owned Clients ---
      # Fix FK User -> Owned Clients (Client table)
      client_col = column_exists?(:clients, :owner_user_id) ? :owner_user_id : :user_id
      if foreign_key_exists?(:clients, column: client_col)
        remove_foreign_key(:clients, column: client_col)
      end
      if column_exists?(:clients, client_col)
        add_foreign_key(:clients, :users, column: client_col, on_delete: :nullify)
      end

      # --- Client Status ---
      remove_column(:clients, :client_status_id) if column_exists?(:clients, :client_status_id)
      add_reference(:clients, :client_status, foreign_key: true, type: :bigint, default: 0, null: false)

      # --- User Telephone ---
      remove_column(:user_telephones, :user_identity_telephone_status_id) if column_exists?(
        :user_telephones,
        :user_identity_telephone_status_id,
      )
      # Note: add_reference suffix _id automatically.
      # Argument is 'user_identity_telephone_status' to imply 'user_identity_telephone_status_id'.
      add_reference(
        :user_telephones, :user_identity_telephone_status,
        foreign_key: { to_table: :user_telephone_statuses }, type: :bigint, default: 0, null: false,
      )

      # --- User Email ---
      remove_column(:user_emails, :user_identity_email_status_id) if column_exists?(
        :user_emails,
        :user_identity_email_status_id,
      )
      add_reference(
        :user_emails, :user_identity_email_status, foreign_key: { to_table: :user_email_statuses },
                                                   type: :bigint, default: 0, null: false,
      )

      # --- User Social Google ---
      remove_column(:user_social_googles, :user_identity_social_google_status_id) if column_exists?(
        :user_social_googles, :user_identity_social_google_status_id,
      )
      add_reference(
        :user_social_googles, :user_identity_social_google_status,
        foreign_key: { to_table: :user_social_google_statuses }, type: :bigint, default: 0, null: false,
      )

      # --- User Social Apple ---
      remove_column(:user_social_apples, :user_identity_social_apple_status_id) if column_exists?(
        :user_social_apples,
        :user_identity_social_apple_status_id,
      )
      add_reference(
        :user_social_apples, :user_identity_social_apple_status,
        foreign_key: { to_table: :user_social_apple_statuses }, type: :bigint, default: 0, null: false,
      )

      # --- User Secret ---
      remove_column(:user_secrets, :user_identity_secret_status_id) if column_exists?(
        :user_secrets,
        :user_identity_secret_status_id,
      )
      add_reference(
        :user_secrets, :user_identity_secret_status, foreign_key: { to_table: :user_secret_statuses },
                                                     type: :bigint, default: 0, null: false,
      )

      remove_column(:user_secrets, :user_secret_kind_id) if column_exists?(:user_secrets, :user_secret_kind_id)
      add_reference(
        :user_secrets, :user_secret_kind, foreign_key: { to_table: :user_secret_kinds }, type: :bigint,
                                          default: 0, null: false,
      )

      # --- User Passkey ---
      remove_column(:user_passkeys, :user_passkey_status_id) if column_exists?(:user_passkeys, :user_passkey_status_id)
      add_reference(
        :user_passkeys, :user_passkey_status, foreign_key: { to_table: :user_passkey_statuses },
                                              type: :bigint, default: 0, null: false,
      )

      # --- User OTP ---
      remove_column(:user_one_time_passwords, :user_identity_one_time_password_status_id) if column_exists?(
        :user_one_time_passwords, :user_identity_one_time_password_status_id,
      )
      add_reference(
        :user_one_time_passwords, :user_identity_one_time_password_status,
        foreign_key: { to_table: :user_one_time_password_statuses }, type: :bigint, default: 0, null: false,
      )
    end
  end

  def down; raise ActiveRecord::IrreversibleMigration; end
end
