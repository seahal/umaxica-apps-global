# frozen_string_literal: true

# Migration to rename status_id columns to match model expectations
# This resolves ForeignKeyTypeChecker warnings for staff identity associations
class RenameStaffIdentityStatusColumns < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    # Remove existing foreign keys first
    remove_foreign_key(:staff_emails, :staff_email_statuses, column: :status_id, if_exists: true)
    remove_foreign_key(:staff_telephones, :staff_telephone_statuses, column: :status_id, if_exists: true)
    remove_foreign_key(:staff_secrets, :staff_secret_statuses, column: :status_id, if_exists: true)
    remove_foreign_key(:staff_passkeys, :staff_passkey_statuses, column: :status_id, if_exists: true)

    # Remove existing indexes
    remove_index(:staff_emails, column: :status_id, if_exists: true)
    remove_index(:staff_secrets, column: :status_id, if_exists: true)

    # Rename columns to match model expectations
    safety_assured do
      rename_column(:staff_emails, :status_id, :staff_identity_email_status_id)
      rename_column(:staff_telephones, :status_id, :staff_identity_telephone_status_id)
      rename_column(:staff_secrets, :status_id, :staff_identity_secret_status_id)
      rename_column(:staff_passkeys, :status_id, :staff_passkey_status_id)
    end

    # Add back foreign keys with new column names
    add_foreign_key(
      :staff_emails, :staff_email_statuses,
      column: :staff_identity_email_status_id,
      on_delete: :restrict,
      validate: false,
    )
    add_foreign_key(
      :staff_telephones, :staff_telephone_statuses,
      column: :staff_identity_telephone_status_id,
      on_delete: :restrict,
      validate: false,
    )
    add_foreign_key(
      :staff_secrets, :staff_secret_statuses,
      column: :staff_identity_secret_status_id,
      on_delete: :restrict,
      validate: false,
    )
    add_foreign_key(
      :staff_passkeys, :staff_passkey_statuses,
      column: :staff_passkey_status_id,
      on_delete: :restrict,
      validate: false,
    )

    # Add indexes for new column names
    add_index(
      :staff_emails, :staff_identity_email_status_id,
      name: "index_staff_emails_on_staff_identity_email_status_id",
      algorithm: :concurrently,
    )
    add_index(
      :staff_telephones, :staff_identity_telephone_status_id,
      name: "index_staff_telephones_on_staff_identity_telephone_status_id",
      algorithm: :concurrently,
    )
    add_index(
      :staff_secrets, :staff_identity_secret_status_id,
      name: "index_staff_secrets_on_staff_identity_secret_status_id",
      algorithm: :concurrently,
    )
    add_index(
      :staff_passkeys, :staff_passkey_status_id,
      name: "index_staff_passkeys_on_staff_passkey_status_id",
      algorithm: :concurrently,
    )
  end
end
