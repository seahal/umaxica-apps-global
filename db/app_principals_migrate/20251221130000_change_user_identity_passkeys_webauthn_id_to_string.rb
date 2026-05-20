# frozen_string_literal: true

class ChangeUserIdentityPasskeysWebauthnIdToString < ActiveRecord::Migration[8.2]
  def up
    change_column(:user_identity_passkeys, :webauthn_id, :string)
  end

  def down
    change_column(:user_identity_passkeys, :webauthn_id, :uuid, using: "webauthn_id::uuid")
  end
end
