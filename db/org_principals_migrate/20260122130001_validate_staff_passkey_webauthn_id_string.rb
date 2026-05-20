# frozen_string_literal: true

class ValidateStaffPasskeyWebauthnIdString < ActiveRecord::Migration[8.0]
  NOT_NULL_CONSTRAINT = "staff_passkeys_webauthn_id_not_null"

  def up
    validate_check_constraint(:staff_passkeys, name: NOT_NULL_CONSTRAINT)
    change_column_null(:staff_passkeys, :webauthn_id, false)
    remove_check_constraint(:staff_passkeys, name: NOT_NULL_CONSTRAINT)
  end

  def down
    add_check_constraint(:staff_passkeys, "webauthn_id IS NOT NULL", name: NOT_NULL_CONSTRAINT, validate: false)
    change_column_null(:staff_passkeys, :webauthn_id, true)
  end
end
