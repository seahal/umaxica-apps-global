# frozen_string_literal: true

class AddCheckConstraintToRoleAssignments < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :role_assignments,
      "(user_id IS NOT NULL AND staff_id IS NULL) OR (staff_id IS NOT NULL AND user_id IS NULL)",
      name: "role_assignments_user_or_staff_check",
    )
  end
end
