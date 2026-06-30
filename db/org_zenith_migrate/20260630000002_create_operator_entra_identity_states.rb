# frozen_string_literal: true

class CreateOperatorEntraIdentityStates < ActiveRecord::Migration[8.2]
  def change
    create_table(:operator_entra_identity_states, id: :bigserial)
  end
end
