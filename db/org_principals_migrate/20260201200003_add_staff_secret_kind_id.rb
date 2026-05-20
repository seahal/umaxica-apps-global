# frozen_string_literal: true

# Migration to add staff_secret_kind_id column to staff_secrets table
# This resolves ForeignKeyTypeChecker warnings for staff_secret_kind association
class AddStaffSecretKindId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column(:staff_secrets, :staff_secret_kind_id, :string)

    add_foreign_key(
      :staff_secrets, :staff_secret_kinds,
      column: :staff_secret_kind_id,
      on_delete: :restrict,
      validate: false,
    )

    add_index(
      :staff_secrets, :staff_secret_kind_id,
      name: "index_staff_secrets_on_staff_secret_kind_id",
      algorithm: :concurrently,
    )
  end
end
