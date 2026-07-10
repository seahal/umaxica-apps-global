# frozen_string_literal: true

class ValidateUserClientForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:user_clients, :users)
    validate_foreign_key(:user_clients, :clients)
  end
end
