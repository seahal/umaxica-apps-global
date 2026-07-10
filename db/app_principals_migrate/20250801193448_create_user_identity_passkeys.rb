# frozen_string_literal: true

class CreateUserIdentityPasskeys < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_identity_passkeys) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.bigint(:webauthn_id, null: false)
      t.text(:public_key, null: false)
      t.string(:description, null: false)
      t.bigint(:sign_count, null: false, default: 0)
      t.bigint(:external_id, null: false)
      t.timestamps
    end

    add_index(:user_identity_passkeys, :webauthn_id, unique: true)
  end
end
