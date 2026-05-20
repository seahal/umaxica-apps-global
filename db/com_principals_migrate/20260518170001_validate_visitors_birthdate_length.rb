# frozen_string_literal: true

class ValidateVisitorsBirthdateLength < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint :visitors, name: "chk_visitors_birthdate_length"
  end
end
