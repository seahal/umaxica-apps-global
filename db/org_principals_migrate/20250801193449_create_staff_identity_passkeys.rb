# frozen_string_literal: true

class CreateStaffIdentityPasskeys < ActiveRecord::Migration[8.0]
  def change
    create_table(:staff_identity_passkeys) do |t|
      t.references(:staff, null: false, foreign_key: true, type: :bigint)
      t.binary(:webauthn_id, null: false)
      t.text(:public_key, null: false)
      t.string(:description, null: false)
      t.bigint(:sign_count, null: false, default: 0)
      t.bigint(:external_id, null: false)
      t.timestamps
    end

    add_index(:staff_identity_passkeys, :webauthn_id, unique: true)
  end
end
