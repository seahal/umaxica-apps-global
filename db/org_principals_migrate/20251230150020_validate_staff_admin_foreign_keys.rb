# frozen_string_literal: true

class ValidateStaffAdminForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:staff_operators, :staffs)
    validate_foreign_key(:staff_operators, :operators)
  end
end
