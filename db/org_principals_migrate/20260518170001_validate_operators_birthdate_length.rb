# frozen_string_literal: true

class ValidateOperatorsBirthdateLength < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint :operators, name: "chk_operators_birthdate_length"
  end
end
