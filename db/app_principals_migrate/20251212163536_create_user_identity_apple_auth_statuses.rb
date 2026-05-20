# frozen_string_literal: true

class CreateUserIdentityAppleAuthStatuses < ActiveRecord::Migration[8.2]
  def up
    create_table(:user_identity_apple_auth_statuses, id: :string, limit: 255, primary_key: :id)

    # Insert default status records
  end

  def down
    drop_table(:user_identity_apple_auth_statuses)
  end
end
