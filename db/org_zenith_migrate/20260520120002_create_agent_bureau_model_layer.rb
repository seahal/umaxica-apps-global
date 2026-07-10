# frozen_string_literal: true

class CreateAgentBureauModelLayer < ActiveRecord::Migration[8.2]
  def change
    create_table(:agent_membership_kinds, id: :bigserial)
    create_table(:agent_membership_states, id: :bigserial)
    create_table(:agent_membership_revoke_reasons, id: :bigserial)

    create_table(:agents, id: :bigserial) do |t|
      t.references(:operator_identity, null: false)
      t.string(:public_id, null: false, default: "")
      t.string(:moniker)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:bureaus, id: :bigserial) do |t|
      t.string(:public_id, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:bureau_units, id: :bigserial) do |t|
      t.references(:bureau, null: false, foreign_key: { validate: false })
      t.references(:parent, foreign_key: { to_table: :bureau_units, validate: false })
      t.string(:public_id, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:bureau_unit_closures, id: :bigserial) do |t|
      t.references(:ancestor, null: false, foreign_key: { to_table: :bureau_units, validate: false })
      t.references(:descendant, null: false, foreign_key: { to_table: :bureau_units, validate: false })
      t.integer(:depth, null: false)
      t.timestamps

      t.index(%i(ancestor_id descendant_id), unique: true, name: "idx_bureau_unit_closures_unique_path")
    end
    add_check_constraint(:bureau_unit_closures, "depth >= 0", name: "chk_bureau_unit_closures_depth_nonnegative")

    create_table(:agent_memberships, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { validate: false })
      t.references(:bureau, null: false, foreign_key: { validate: false })
      t.references(:bureau_unit, null: false, foreign_key: { validate: false })
      t.bigint(:membership_kind_id, null: false, default: 0)
      t.bigint(:membership_state_id, null: false, default: 0)
      t.boolean(:primary, null: false, default: false)
      t.datetime(:starts_at)
      t.datetime(:ends_at)
      t.bigint(:granted_by_agent_id)
      t.bigint(:approved_by_agent_id)
      t.bigint(:revoked_by_agent_id)
      t.datetime(:revoked_at)
      t.bigint(:revoke_reason_id)
      t.jsonb(:metadata, null: false, default: {})
      t.timestamps

      t.index(:membership_kind_id)
      t.index(:membership_state_id)
      t.index(:granted_by_agent_id)
      t.index(:approved_by_agent_id)
      t.index(:revoked_by_agent_id)
      t.index(:revoke_reason_id)
      t.index(:agent_id, unique: true, where: "\"primary\" = TRUE AND revoked_at IS NULL AND ends_at IS NULL",
                         name: "idx_agent_memberships_one_active_primary")
    end

    add_foreign_key(:agent_memberships, :agent_membership_kinds, column: :membership_kind_id, validate: false)
    add_foreign_key(:agent_memberships, :agent_membership_states, column: :membership_state_id, validate: false)
    add_foreign_key(:agent_memberships, :agent_membership_revoke_reasons, column: :revoke_reason_id, validate: false)
    add_foreign_key(:agent_memberships, :agents, column: :granted_by_agent_id, validate: false)
    add_foreign_key(:agent_memberships, :agents, column: :approved_by_agent_id, validate: false)
    add_foreign_key(:agent_memberships, :agents, column: :revoked_by_agent_id, validate: false)
  end
end
