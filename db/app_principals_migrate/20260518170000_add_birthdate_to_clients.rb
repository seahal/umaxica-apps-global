# frozen_string_literal: true

class AddBirthdateToClients < ActiveRecord::Migration[8.2]
  CONSTRAINT_NAME = "chk_clients_birthdate_length"

  def change
    add_column :users, :birthdate, :text unless column_exists?(:users, :birthdate)

    add_check_constraint(
      :users,
      "birthdate IS NULL OR char_length(birthdate) <= 1000",
      name: CONSTRAINT_NAME,
      if_not_exists: true,
      validate: false,
    )
  end
end
