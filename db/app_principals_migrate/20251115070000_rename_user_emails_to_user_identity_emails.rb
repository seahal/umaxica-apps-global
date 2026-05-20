# frozen_string_literal: true

class RenameUserEmailsToUserIdentityEmails < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:user_emails)

    rename_table(:user_emails, :user_identity_emails)

    # Check if index still has old name before renaming
    return unless index_exists?(:user_identity_emails, :user_id, name: "index_user_emails_on_user_id")

    rename_index(
      :user_identity_emails,
      "index_user_emails_on_user_id",
      "index_user_identity_emails_on_user_id",
    )

  end

  def down
    return unless table_exists?(:user_identity_emails)

    rename_index(
      :user_identity_emails,
      "index_user_identity_emails_on_user_id",
      "index_user_emails_on_user_id",
    )
    rename_table(:user_identity_emails, :user_emails)
  end
end
