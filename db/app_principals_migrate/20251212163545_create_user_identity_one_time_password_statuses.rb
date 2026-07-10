# frozen_string_literal: true

class CreateUserIdentityOneTimePasswordStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_identity_one_time_password_statuses, id: :string, primary_key: :id)

    add_column(:user_identity_one_time_passwords, :user_identity_one_time_password_status_id, :string)
    add_foreign_key(
      :user_identity_one_time_passwords, :user_identity_one_time_password_statuses,
      column: :user_identity_one_time_password_status_id, primary_key: :id,
    )
  end
end
