# frozen_string_literal: true

class CreateIndividualCompanyModelLayer < ActiveRecord::Migration[8.2]
  def change
    create_table(:individual_membership_kinds, id: :bigserial)
    create_table(:individual_membership_states, id: :bigserial)
    create_table(:individual_membership_revoke_reasons, id: :bigserial)

    create_table(:individuals, id: :bigserial) do |t|
      t.references(:visitor_identity, null: false)
      t.string(:public_id, null: false, default: "")
      t.string(:moniker)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:companies, id: :bigserial) do |t|
      t.string(:public_id, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:company_units, id: :bigserial) do |t|
      t.references(:company, null: false, foreign_key: { validate: false })
      t.references(:parent, foreign_key: { to_table: :company_units, validate: false })
      t.string(:public_id, null: false, default: "")
      t.string(:name, null: false, default: "")
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true)
    end

    create_table(:company_unit_closures, id: :bigserial) do |t|
      t.references(:ancestor, null: false, foreign_key: { to_table: :company_units, validate: false })
      t.references(:descendant, null: false, foreign_key: { to_table: :company_units, validate: false })
      t.integer(:depth, null: false)
      t.timestamps

      t.index(%i(ancestor_id descendant_id), unique: true, name: "idx_company_unit_closures_unique_path")
    end
    add_check_constraint(:company_unit_closures, "depth >= 0", name: "chk_company_unit_closures_depth_nonnegative")

    create_table(:individual_memberships, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { validate: false })
      t.references(:company, null: false, foreign_key: { validate: false })
      t.references(:company_unit, null: false, foreign_key: { validate: false })
      t.bigint(:membership_kind_id, null: false, default: 0)
      t.bigint(:membership_state_id, null: false, default: 0)
      t.boolean(:primary, null: false, default: false)
      t.datetime(:starts_at)
      t.datetime(:ends_at)
      t.bigint(:granted_by_individual_id)
      t.bigint(:approved_by_individual_id)
      t.bigint(:revoked_by_individual_id)
      t.datetime(:revoked_at)
      t.bigint(:revoke_reason_id)
      t.jsonb(:metadata, null: false, default: {})
      t.timestamps

      t.index(:membership_kind_id)
      t.index(:membership_state_id)
      t.index(:granted_by_individual_id)
      t.index(:approved_by_individual_id)
      t.index(:revoked_by_individual_id)
      t.index(:revoke_reason_id)
      t.index(:individual_id, unique: true, where: "\"primary\" = TRUE AND revoked_at IS NULL AND ends_at IS NULL",
                              name: "idx_individual_memberships_one_active_primary")
    end

    add_foreign_key(:individual_memberships, :individual_membership_kinds, column: :membership_kind_id, validate: false)
    add_foreign_key(:individual_memberships, :individual_membership_states, column: :membership_state_id, validate: false)
    add_foreign_key(:individual_memberships, :individual_membership_revoke_reasons, column: :revoke_reason_id, validate: false)
    add_foreign_key(:individual_memberships, :individuals, column: :granted_by_individual_id, validate: false)
    add_foreign_key(:individual_memberships, :individuals, column: :approved_by_individual_id, validate: false)
    add_foreign_key(:individual_memberships, :individuals, column: :revoked_by_individual_id, validate: false)
  end
end
