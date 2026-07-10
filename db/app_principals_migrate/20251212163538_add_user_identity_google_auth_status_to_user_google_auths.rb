# frozen_string_literal: true

class AddUserIdentityGoogleAuthStatusToUserGoogleAuths < ActiveRecord::Migration[8.2]
  def change
    unless column_exists?(:user_google_auths, :user_identity_google_auth_status_id)
      add_column(
        :user_google_auths, :user_identity_google_auth_status_id, :string, limit: 255, default: "ACTIVE",
                                                                           null: false,
      )
    end

    unless index_exists?(:user_google_auths, :user_identity_google_auth_status_id)
      add_index(:user_google_auths, :user_identity_google_auth_status_id)
    end

    return if foreign_key_exists?(:user_google_auths, :user_identity_google_auth_statuses)

    add_foreign_key(
      :user_google_auths, :user_identity_google_auth_statuses,
      column: :user_identity_google_auth_status_id, primary_key: :id,
    )

  end
end
