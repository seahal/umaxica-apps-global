# frozen_string_literal: true

class ValidateAdministrativeAccessLockOnClients < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:clients, name: "chk_clients_access_state")
    validate_check_constraint(:clients, name: "chk_clients_admin_locked_reason_code")
  end
end
