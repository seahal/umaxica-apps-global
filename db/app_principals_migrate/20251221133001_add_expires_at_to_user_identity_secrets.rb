# frozen_string_literal: true

class AddExpiresAtToUserIdentitySecrets < ActiveRecord::Migration[8.2]
  def change
    add_column(:user_identity_secrets, :expires_at, :datetime, null: false, default: -> { "'infinity'" })
    add_index(:user_identity_secrets, :expires_at)
  end
end
