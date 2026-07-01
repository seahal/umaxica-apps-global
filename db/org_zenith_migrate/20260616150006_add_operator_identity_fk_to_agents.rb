# frozen_string_literal: true

class AddOperatorIdentityFkToAgents < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key :agents, :operator_identities, column: :operator_identity_id, on_delete: :restrict,
                    validate: false
  end
end
