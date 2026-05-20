# frozen_string_literal: true

class RenameOperatorTables < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      rename_table(:admin_identity_statuses, :operator_statuses)

      rename_table(:staff_identity_emails, :staff_emails)
      rename_table(:staff_identity_telephones, :staff_telephones)
      rename_table(:staff_identity_secrets, :staff_secrets)
      rename_table(:staff_identity_statuses, :staff_statuses)

      rename_table(:staff_identity_email_statuses, :staff_email_statuses)
      rename_table(:staff_identity_telephone_statuses, :staff_telephone_statuses)
      rename_table(:staff_identity_secret_statuses, :staff_secret_statuses)
      rename_table(:staff_identity_passkey_statuses, :staff_passkey_statuses)

      rename_table(:workspaces, :organizations)
      rename_table(:department_statuses, :organization_statuses)
    end
  end
end
