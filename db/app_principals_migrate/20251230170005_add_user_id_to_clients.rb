# frozen_string_literal: true

class AddUserIdToClients < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      add_reference(
        :clients,
        :user,
        foreign_key: { to_table: :users, validate: false },
        type: :bigint,
      )
    end
  end
end
