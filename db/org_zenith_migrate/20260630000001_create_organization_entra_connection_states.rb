# frozen_string_literal: true

class CreateOrganizationEntraConnectionStates < ActiveRecord::Migration[8.2]
  def change
    create_table(:organization_entra_connection_states, id: :bigserial)
  end
end
