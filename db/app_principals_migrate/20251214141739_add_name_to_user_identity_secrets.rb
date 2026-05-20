# frozen_string_literal: true

class AddNameToUserIdentitySecrets < ActiveRecord::Migration[8.2]
  def change
    add_column(:user_identity_secrets, :name, :string)
  end
end
