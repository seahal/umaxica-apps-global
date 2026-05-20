# frozen_string_literal: true

class CreateStaffAdmins < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_operators) do |t|
      t.bigint(:staff_id, null: false)
      t.bigint(:admin_id, null: false)

      t.timestamps
    end

    add_index(:staff_operators, [:staff_id, :admin_id], unique: true)
    add_index(:staff_operators, :staff_id)
    add_index(:staff_operators, :admin_id)

    add_foreign_key(:staff_operators, :staffs, on_delete: :cascade, validate: false)
    add_foreign_key(:staff_operators, :operators, column: :admin_id, on_delete: :cascade, validate: false)
  end
end
