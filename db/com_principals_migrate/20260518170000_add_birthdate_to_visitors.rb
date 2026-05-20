# frozen_string_literal: true

class AddBirthdateToVisitors < ActiveRecord::Migration[8.2]
  CONSTRAINT_NAME = "chk_visitors_birthdate_length"

  def change
    add_column :visitors, :birthdate, :text unless column_exists?(:visitors, :birthdate)

    add_check_constraint(
      :visitors,
      "birthdate IS NULL OR char_length(birthdate) <= 1000",
      name: CONSTRAINT_NAME,
      if_not_exists: true,
      validate: false,
    )
  end
end
