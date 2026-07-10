# frozen_string_literal: true

class RenameStaffEmailsToStaffIdentityEmails < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:staff_emails)

    rename_table(:staff_emails, :staff_identity_emails)

    # Check if index still has old name before renaming
    return unless index_exists?(:staff_identity_emails, :staff_id, name: "index_staff_emails_on_staff_id")

    rename_index(
      :staff_identity_emails,
      "index_staff_emails_on_staff_id",
      "index_staff_identity_emails_on_staff_id",
    )

  end

  def down
    return unless table_exists?(:staff_identity_emails)

    rename_index(
      :staff_identity_emails,
      "index_staff_identity_emails_on_staff_id",
      "index_staff_emails_on_staff_id",
    )
    rename_table(:staff_identity_emails, :staff_emails)
  end
end
