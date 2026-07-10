# frozen_string_literal: true

class CreateOperatorWorkspaceAccountTables < ActiveRecord::Migration[8.2]
  def change
    create_table(:operator_workspace_accounts, id: :bigserial) do |t|
      t.bigint(:staff_id, null: false)
      t.bigint(:department_id)
      t.string(:public_id, null: false)
      t.string(:moniker)
      t.integer(:lock_version, default: 0, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)
      t.bigint(:status_id, default: 0, null: false)

      t.index(:department_id)
      t.index(:public_id, unique: true)
      t.index(:staff_id)
      t.index(:status_id)
    end

    create_table(:operator_workspace_account_memberships, id: :bigserial) do |t|
      t.bigint(:staff_id, null: false)
      t.bigint(:operator_workspace_account_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:operator_workspace_account_id, name: "idx_operator_workspace_memberships_on_account_id")
      t.index(
        %i(staff_id operator_workspace_account_id),
        unique: true,
        name: "idx_operator_workspace_memberships_on_staff_and_account",
      )
    end

    add_foreign_key(
      :operator_workspace_account_memberships,
      :operator_workspace_accounts,
      on_delete: :cascade,
      validate: false,
    )
  end
end
