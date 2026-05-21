# frozen_string_literal: true

class CreatePersonaEnterpriseModelLayer < ActiveRecord::Migration[8.2]
  def change
    create_table(:persona_membership_kinds, id: :bigserial)
    create_table(:persona_membership_states, id: :bigserial)
    create_table(:persona_membership_revoke_reasons, id: :bigserial)

    create_table(:personas, id: :bigserial) do |t|
      t.references(:client_identity, null: false)
      t.string(:public_id, null: false, default: "")
      t.string(:moniker)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:enterprises, id: :bigserial) do |t|
      t.string(:public_id, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:enterprise_units, id: :bigserial) do |t|
      t.references(:enterprise, null: false, foreign_key: { validate: false })
      t.references(:parent, foreign_key: { to_table: :enterprise_units, validate: false })
      t.string(:public_id, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:enterprise_unit_closures, id: :bigserial) do |t|
      t.references(:ancestor, null: false, foreign_key: { to_table: :enterprise_units, validate: false })
      t.references(:descendant, null: false, foreign_key: { to_table: :enterprise_units, validate: false })
      t.integer(:depth, null: false)
      t.timestamps

      t.index(%i(ancestor_id descendant_id), unique: true, name: "idx_enterprise_unit_closures_unique_path")
    end
    add_check_constraint(:enterprise_unit_closures, "depth >= 0", name: "chk_enterprise_unit_closures_depth_nonnegative")

    create_table(:persona_memberships, id: :bigserial) do |t|
      t.references(:persona, null: false, foreign_key: { validate: false })
      t.references(:enterprise, null: false, foreign_key: { validate: false })
      t.references(:enterprise_unit, null: false, foreign_key: { validate: false })
      t.bigint(:membership_kind_id, null: false, default: 0)
      t.bigint(:membership_state_id, null: false, default: 0)
      t.boolean(:primary, null: false, default: false)
      t.datetime(:starts_at)
      t.datetime(:ends_at)
      t.bigint(:granted_by_persona_id)
      t.bigint(:approved_by_persona_id)
      t.bigint(:revoked_by_persona_id)
      t.datetime(:revoked_at)
      t.bigint(:revoke_reason_id)
      t.jsonb(:metadata, null: false, default: {})
      t.timestamps

      t.index(:membership_kind_id)
      t.index(:membership_state_id)
      t.index(:granted_by_persona_id)
      t.index(:approved_by_persona_id)
      t.index(:revoked_by_persona_id)
      t.index(:revoke_reason_id)
      t.index(:persona_id, unique: true, where: "\"primary\" = TRUE AND revoked_at IS NULL AND ends_at IS NULL",
                           name: "idx_persona_memberships_one_active_primary")
    end

    add_foreign_key(:persona_memberships, :persona_membership_kinds, column: :membership_kind_id, validate: false)
    add_foreign_key(:persona_memberships, :persona_membership_states, column: :membership_state_id, validate: false)
    add_foreign_key(:persona_memberships, :persona_membership_revoke_reasons, column: :revoke_reason_id, validate: false)
    add_foreign_key(:persona_memberships, :personas, column: :granted_by_persona_id, validate: false)
    add_foreign_key(:persona_memberships, :personas, column: :approved_by_persona_id, validate: false)
    add_foreign_key(:persona_memberships, :personas, column: :revoked_by_persona_id, validate: false)
  end
end
