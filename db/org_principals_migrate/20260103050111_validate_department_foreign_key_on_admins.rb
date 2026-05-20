# frozen_string_literal: true

class ValidateDepartmentForeignKeyOnAdmins < ActiveRecord::Migration[8.2]
  def change
    return unless foreign_key_exists?(:operators, :departments, column: :department_id)

    validate_foreign_key(:operators, :departments)
  end
end
