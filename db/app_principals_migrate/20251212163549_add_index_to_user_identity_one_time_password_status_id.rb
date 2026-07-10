# frozen_string_literal: true

class AddIndexToUserIdentityOneTimePasswordStatusId < ActiveRecord::Migration[8.2]
  def change
    add_index(:user_identity_one_time_passwords, :user_identity_one_time_password_status_id) unless index_exists?(
      :user_identity_one_time_passwords, :user_identity_one_time_password_status_id,
    )
  end
end
