# frozen_string_literal: true

class CreateAvatarAccountBindings < ActiveRecord::Migration[8.2]
  def change
    create_table(:avatar_persona_bindings) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.references(:avatar, null: false, index: false)
      t.references(:persona, null: false, index: false)
      t.datetime(:assigned_at, null: false)
      t.datetime(:revoked_at)
      t.timestamps

      t.index(:public_id, unique: true)
      t.index(:avatar_id)
      t.index(:persona_id)
      t.index(
        [:avatar_id, :persona_id],
        unique: true,
        where: "revoked_at IS NULL",
        name: "idx_avatar_persona_bindings_active_pair",
      )
      t.index(
        :avatar_id,
        unique: true,
        where: "revoked_at IS NULL",
        name: "idx_avatar_persona_bindings_active_avatar",
      )
      t.index(
        :persona_id,
        unique: true,
        where: "revoked_at IS NULL",
        name: "idx_avatar_persona_bindings_active_persona",
      )
    end

    create_table(:avatar_agent_bindings) do |t|
      t.references(:avatar, null: false, index: { unique: true })
      t.references(:agent, null: false, index: { unique: true })
      t.timestamps
    end

    create_table(:avatar_individual_bindings) do |t|
      t.references(:avatar, null: false, index: { unique: true })
      t.references(:individual, null: false, index: { unique: true })
      t.timestamps
    end
  end
end
