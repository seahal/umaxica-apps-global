# frozen_string_literal: true

class ValidateAdminStaffForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:operators, :staffs)
  end
end
