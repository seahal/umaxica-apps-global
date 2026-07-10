# frozen_string_literal: true

class ValidateNotNullAdminStaffId < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:operators, name: "operators_staff_id_null")
    change_column_null(:operators, :staff_id, false)
    remove_check_constraint(:operators, name: "operators_staff_id_null")
  end

  def down
    add_check_constraint(
      :operators, "staff_id IS NOT NULL",
      name: "operators_staff_id_null",
      validate: false,
    )
    change_column_null(:operators, :staff_id, true)
  end
end
