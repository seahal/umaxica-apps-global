# frozen_string_literal: true

class HardenPersonaEnterpriseModelLayerConstraints < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(:personas, :client_identity_id, unique: true, name: "idx_personas_one_per_client_identity",
                                                   algorithm: :concurrently) unless
      index_exists?(:personas, :client_identity_id, name: "idx_personas_one_per_client_identity")
    add_index(:enterprise_units, %i(id enterprise_id), unique: true, name: "idx_enterprise_units_id_enterprise",
                                                          algorithm: :concurrently) unless
      index_exists?(:enterprise_units, %i(id enterprise_id), name: "idx_enterprise_units_id_enterprise")

    unless foreign_key_exists?(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise")
      add_foreign_key(
        :enterprise_units,
        :enterprise_units,
        column: %i(parent_id enterprise_id),
        primary_key: %i(id enterprise_id),
        validate: false,
        name: "fk_enterprise_units_parent_same_enterprise",
      )
    end
    unless foreign_key_exists?(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise")
      add_foreign_key(
        :persona_memberships,
        :enterprise_units,
        column: %i(enterprise_unit_id enterprise_id),
        primary_key: %i(id enterprise_id),
        validate: false,
        name: "fk_persona_memberships_unit_same_enterprise",
      )
    end

    return if check_constraint_exists?(:enterprise_unit_closures, name: "chk_enterprise_unit_closures_depth_matches_self")

    add_check_constraint(
      :enterprise_unit_closures,
      "(ancestor_id = descendant_id AND depth = 0) OR (ancestor_id <> descendant_id AND depth > 0)",
      name: "chk_enterprise_unit_closures_depth_matches_self",
      validate: false,
    )
  end

  def down
    remove_check_constraint(:enterprise_unit_closures, name: "chk_enterprise_unit_closures_depth_matches_self") if
      check_constraint_exists?(:enterprise_unit_closures, name: "chk_enterprise_unit_closures_depth_matches_self")
    remove_foreign_key(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise") if
      foreign_key_exists?(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise")
    remove_foreign_key(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise") if
      foreign_key_exists?(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise")
    remove_index(:enterprise_units, name: "idx_enterprise_units_id_enterprise", algorithm: :concurrently) if
      index_exists?(:enterprise_units, name: "idx_enterprise_units_id_enterprise")
    remove_index(:personas, name: "idx_personas_one_per_client_identity", algorithm: :concurrently) if
      index_exists?(:personas, name: "idx_personas_one_per_client_identity")
  end
end
