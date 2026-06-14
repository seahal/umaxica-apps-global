# frozen_string_literal: true

class ValidateAdministrativeAccessLockOnVisitors < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:visitors, name: "chk_visitors_access_state")
    validate_check_constraint(:visitors, name: "chk_visitors_admin_locked_reason_code")
  end
end
