# frozen_string_literal: true

class ValidateClientFkBehaviors < ActiveRecord::Migration[8.2]
  def change
    validate_client_fk(:clients, :users, :user_id)
    validate_client_fk(:client_avatars, :clients, :client_id)
  end

  private

  def validate_client_fk(from_table, to_table, column)
    return unless foreign_key_exists?(from_table, to_table, column: column)

    validate_foreign_key(from_table, to_table)
  end
end
