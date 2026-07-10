# frozen_string_literal: true

class CreateAgentAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table(:agent_assignments, id: :bigserial) do |t|
      t.string(:public_id, null: false)
      t.references(:agent, null: false, foreign_key: { validate: false })
      t.references(:operator_identity, null: false, foreign_key: { validate: false })
      t.datetime(:assigned_at, null: false)
      t.datetime(:revoked_at)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(agent_id operator_identity_id), unique: true, where: "revoked_at IS NULL",
               name: "idx_agent_assignments_one_active_identity_per_agent")
    end
  end
end
