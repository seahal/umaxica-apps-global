# frozen_string_literal: true

class ValidateClientsBirthdateLength < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint :users, name: "chk_clients_birthdate_length"
  end
end
