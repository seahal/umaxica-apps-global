# frozen_string_literal: true

class AddStaffIdentityPasskeyStatusToStaffIdentityPasskeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    unless column_exists?(:staff_identity_passkeys, :staff_identity_passkey_status_id)
      add_column(
        :staff_identity_passkeys, :staff_identity_passkey_status_id, :string,
        limit: 255, default: "ACTIVE", null: false,
      )
    end

    unless index_exists?(:staff_identity_passkeys, :staff_identity_passkey_status_id)
      add_index(:staff_identity_passkeys, :staff_identity_passkey_status_id, algorithm: :concurrently)
    end

    return if foreign_key_exists?(:staff_identity_passkeys, :staff_identity_passkey_statuses)

    add_foreign_key(
      :staff_identity_passkeys, :staff_identity_passkey_statuses,
      column: :staff_identity_passkey_status_id, primary_key: :id, validate: false,
    )

  end
end
