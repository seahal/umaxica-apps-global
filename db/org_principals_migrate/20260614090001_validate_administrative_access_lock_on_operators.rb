# frozen_string_literal: true

class ValidateAdministrativeAccessLockOnOperators < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:operators, name: "chk_operators_access_state")
    validate_check_constraint(:operators, name: "chk_operators_admin_locked_reason_code")
  end
end
