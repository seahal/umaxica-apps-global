# frozen_string_literal: true

class FixClientFkBehaviors < ActiveRecord::Migration[8.2]
  def change
    add_client_fk(:clients, :users, :user_id)
    add_client_fk(:client_avatars, :clients, :client_id)
  end

  private

  def add_client_fk(from_table, to_table, column)
    return unless table_exists?(from_table) && table_exists?(to_table)
    return if foreign_key_exists?(from_table, to_table, column: column)

    add_foreign_key(
      from_table, to_table,
      column: column,
      on_delete: :nullify,
      validate: false,
    )
  end
end
