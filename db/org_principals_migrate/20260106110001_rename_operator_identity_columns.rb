# frozen_string_literal: true

class RenameOperatorIdentityColumns < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      safe_rename_column(:staff_emails, :staff_identity_email_status_id, :staff_email_status_id)
      safe_rename_column(:staff_passkeys, :staff_identity_passkey_status_id, :staff_passkey_status_id)
      safe_rename_column(:staff_secrets, :staff_identity_secret_status_id, :staff_secret_status_id)
      safe_rename_column(:staff_telephones, :staff_identity_telephone_status_id, :staff_telephone_status_id)
    end
  end

  def down
    safety_assured do
      safe_rename_column(:staff_emails, :staff_email_status_id, :staff_identity_email_status_id)
      safe_rename_column(:staff_passkeys, :staff_passkey_status_id, :staff_identity_passkey_status_id)
      safe_rename_column(:staff_secrets, :staff_secret_status_id, :staff_identity_secret_status_id)
      safe_rename_column(:staff_telephones, :staff_telephone_status_id, :staff_identity_telephone_status_id)
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
