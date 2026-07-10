# frozen_string_literal: true

class AddUsesRemainingToUserIdentitySecrets < ActiveRecord::Migration[8.2]
  def change
    add_column(:user_identity_secrets, :uses_remaining, :integer, default: 1, null: false)

    add_check_constraint(
      :user_identity_secrets, "uses_remaining >= 0",
      name: "chk_user_identity_secrets_uses_remaining_non_negative",
    )

    add_index(:user_identity_secrets, :user_id) unless index_exists?(:user_identity_secrets, :user_id)
  end
end
