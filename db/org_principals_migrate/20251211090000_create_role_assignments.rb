# frozen_string_literal: true

class CreateRoleAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table(:role_assignments) do |t|
      t.bigint(:user_id)
      t.bigint(:staff_id)
      t.bigint(:role_id, null: false)

      t.timestamps
    end

    add_index(:role_assignments, :user_id)
    add_index(:role_assignments, :staff_id)
    add_index(
      :role_assignments, [:user_id, :role_id],
      unique: true, name: "index_role_assignments_on_user_role",
    )
    add_index(
      :role_assignments, [:staff_id, :role_id],
      unique: true, name: "index_role_assignments_on_staff_role",
    )
    add_index(:role_assignments, :role_id)

    # add_foreign_key :role_assignments, :roles
    # add_foreign_key :role_assignments, :users, on_delete: :cascade
    add_foreign_key(:role_assignments, :staffs, on_delete: :cascade)
  end
end
