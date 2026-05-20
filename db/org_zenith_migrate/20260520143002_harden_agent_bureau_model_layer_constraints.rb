# frozen_string_literal: true

class HardenAgentBureauModelLayerConstraints < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(:agents, :operator_identity_id, unique: true, name: "idx_agents_one_per_operator_identity",
                                                   algorithm: :concurrently) unless
      index_exists?(:agents, :operator_identity_id, name: "idx_agents_one_per_operator_identity")
    add_index(:bureau_units, %i(id bureau_id), unique: true, name: "idx_bureau_units_id_bureau",
                                                    algorithm: :concurrently) unless
      index_exists?(:bureau_units, %i(id bureau_id), name: "idx_bureau_units_id_bureau")

    unless foreign_key_exists?(:bureau_units, name: "fk_bureau_units_parent_same_bureau")
      add_foreign_key(
        :bureau_units,
        :bureau_units,
        column: %i(parent_id bureau_id),
        primary_key: %i(id bureau_id),
        validate: false,
        name: "fk_bureau_units_parent_same_bureau",
      )
    end
    unless foreign_key_exists?(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau")
      add_foreign_key(
        :agent_memberships,
        :bureau_units,
        column: %i(bureau_unit_id bureau_id),
        primary_key: %i(id bureau_id),
        validate: false,
        name: "fk_agent_memberships_unit_same_bureau",
      )
    end

    return if check_constraint_exists?(:bureau_unit_closures, name: "chk_bureau_unit_closures_depth_matches_self")

    add_check_constraint(
      :bureau_unit_closures,
      "(ancestor_id = descendant_id AND depth = 0) OR (ancestor_id <> descendant_id AND depth > 0)",
      name: "chk_bureau_unit_closures_depth_matches_self",
      validate: false,
    )
  end

  def down
    remove_check_constraint(:bureau_unit_closures, name: "chk_bureau_unit_closures_depth_matches_self") if
      check_constraint_exists?(:bureau_unit_closures, name: "chk_bureau_unit_closures_depth_matches_self")
    remove_foreign_key(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau") if
      foreign_key_exists?(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau")
    remove_foreign_key(:bureau_units, name: "fk_bureau_units_parent_same_bureau") if
      foreign_key_exists?(:bureau_units, name: "fk_bureau_units_parent_same_bureau")
    remove_index(:bureau_units, name: "idx_bureau_units_id_bureau", algorithm: :concurrently) if
      index_exists?(:bureau_units, name: "idx_bureau_units_id_bureau")
    remove_index(:agents, name: "idx_agents_one_per_operator_identity", algorithm: :concurrently) if
      index_exists?(:agents, name: "idx_agents_one_per_operator_identity")
  end
end
