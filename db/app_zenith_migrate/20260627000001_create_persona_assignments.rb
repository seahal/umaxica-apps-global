# frozen_string_literal: true

class CreatePersonaAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table(:persona_assignments, id: :bigserial) do |t|
      t.string(:public_id, null: false)
      t.references(:persona, null: false, foreign_key: { validate: false })
      t.references(:client_identity, null: false, foreign_key: { validate: false })
      t.datetime(:assigned_at, null: false)
      t.datetime(:revoked_at)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(persona_id client_identity_id), unique: true, where: "revoked_at IS NULL",
               name: "idx_persona_assignments_one_active_identity_per_persona")
    end
  end
end
