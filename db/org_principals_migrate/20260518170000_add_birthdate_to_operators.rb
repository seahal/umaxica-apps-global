# frozen_string_literal: true

class AddBirthdateToOperators < ActiveRecord::Migration[8.2]
  CONSTRAINT_NAME = "chk_operators_birthdate_length"

  def change
    add_column :operators, :birthdate, :text unless column_exists?(:operators, :birthdate)

    add_check_constraint(
      :operators,
      "birthdate IS NULL OR char_length(birthdate) <= 1000",
      name: CONSTRAINT_NAME,
      if_not_exists: true,
      validate: false,
    )
  end
end
