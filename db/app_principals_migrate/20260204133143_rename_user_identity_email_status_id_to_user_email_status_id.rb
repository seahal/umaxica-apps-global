# frozen_string_literal: true

class RenameUserIdentityEmailStatusIdToUserEmailStatusId < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      remove_foreign_key(:user_emails, column: :user_identity_email_status_id)
      remove_index(:user_emails, name: :index_user_emails_on_user_identity_email_status_id)
      rename_column(:user_emails, :user_identity_email_status_id, :user_email_status_id)
      add_index(:user_emails, :user_email_status_id)
      add_foreign_key(:user_emails, :user_email_statuses, column: :user_email_status_id)
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:user_emails, column: :user_email_status_id)
      remove_index(:user_emails, column: :user_email_status_id)
      rename_column(:user_emails, :user_email_status_id, :user_identity_email_status_id)
      add_index(
        :user_emails, :user_identity_email_status_id,
        name: :index_user_emails_on_user_identity_email_status_id,
      )
      add_foreign_key(:user_emails, :user_email_statuses, column: :user_identity_email_status_id)
    end
  end
end
