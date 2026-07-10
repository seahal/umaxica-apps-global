# frozen_string_literal: true

class CreateIndividualAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table(:individual_assignments, id: :bigserial) do |t|
      t.string(:public_id, null: false)
      t.references(:individual, null: false, foreign_key: { validate: false })
      t.references(:visitor_identity, null: false, foreign_key: { validate: false })
      t.datetime(:assigned_at, null: false)
      t.datetime(:revoked_at)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(%i(individual_id visitor_identity_id), unique: true, where: "revoked_at IS NULL",
               name: "idx_individual_assignments_one_active_identity_per_individual")
    end
  end
end
