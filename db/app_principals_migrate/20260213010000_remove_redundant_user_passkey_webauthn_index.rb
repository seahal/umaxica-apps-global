# frozen_string_literal: true

class RemoveRedundantUserPasskeyWebauthnIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  REDUNDANT_INDEX = "index_user_identity_passkeys_on_webauthn_id"
  def up
    safety_assured do
      remove_index(:user_passkeys, name: REDUNDANT_INDEX, algorithm: :concurrently, if_exists: true)
    end
  end

  def down
    safety_assured do
      add_index(
        :user_passkeys, :webauthn_id,
        unique: true,
        name: REDUNDANT_INDEX,
        algorithm: :concurrently,
        if_not_exists: true,
      )
    end
  end
end
