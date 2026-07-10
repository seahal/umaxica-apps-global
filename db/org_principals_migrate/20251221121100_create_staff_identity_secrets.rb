# frozen_string_literal: true

class CreateStaffIdentitySecrets < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_identity_secrets) do |t|
      t.references(:staff, null: false, foreign_key: true, type: :bigint)
      t.string(:password_digest)
      t.datetime(:last_used_at)
      t.string(:name)
      t.string(:staff_identity_secret_status_id, limit: 255, default: "ACTIVE", null: false)

      t.timestamps
    end

    add_index(:staff_identity_secrets, :staff_identity_secret_status_id)
    add_foreign_key(
      :staff_identity_secrets, :staff_identity_secret_statuses,
      column: :staff_identity_secret_status_id, primary_key: :id,
    )
  end
end
