# frozen_string_literal: true

class AddClientFkToClientPreferences < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key :client_preferences, :clients, column: :user_id, on_delete: :cascade, validate: false
  end
end
