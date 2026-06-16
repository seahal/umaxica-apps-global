# frozen_string_literal: true

class AddClientIdentityFkToPersonas < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key :personas, :client_identities, column: :client_identity_id, on_delete: :restrict,
                    validate: false
  end
end
