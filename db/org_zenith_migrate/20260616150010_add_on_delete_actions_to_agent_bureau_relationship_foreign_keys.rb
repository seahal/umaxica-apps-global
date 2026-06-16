# frozen_string_literal: true

class AddOnDeleteActionsToAgentBureauRelationshipForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau") if
      foreign_key_exists?(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau")
    remove_foreign_key(:bureau_units, name: "fk_bureau_units_parent_same_bureau") if
      foreign_key_exists?(:bureau_units, name: "fk_bureau_units_parent_same_bureau")
    remove_foreign_key(:agent_memberships, column: :approved_by_agent_id) if foreign_key_exists?(:agent_memberships, column: :approved_by_agent_id)
    remove_foreign_key(:agent_memberships, column: :granted_by_agent_id) if foreign_key_exists?(:agent_memberships, column: :granted_by_agent_id)
    remove_foreign_key(:agent_memberships, column: :revoked_by_agent_id) if foreign_key_exists?(:agent_memberships, column: :revoked_by_agent_id)

    add_foreign_key(
      :agent_memberships,
      :bureau_units,
      column: %i[bureau_unit_id bureau_id],
      primary_key: %i[id bureau_id],
      on_delete: :restrict,
      validate: false,
      name: "fk_agent_memberships_unit_same_bureau",
    )
    add_foreign_key(
      :bureau_units,
      :bureau_units,
      column: %i[parent_id bureau_id],
      primary_key: %i[id bureau_id],
      on_delete: :restrict,
      validate: false,
      name: "fk_bureau_units_parent_same_bureau",
    )
    add_foreign_key :agent_memberships, :agents, column: :approved_by_agent_id, on_delete: :nullify, validate: false
    add_foreign_key :agent_memberships, :agents, column: :granted_by_agent_id, on_delete: :nullify, validate: false
    add_foreign_key :agent_memberships, :agents, column: :revoked_by_agent_id, on_delete: :nullify, validate: false
  end

  def down
    remove_foreign_key(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau") if
      foreign_key_exists?(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau")
    remove_foreign_key(:bureau_units, name: "fk_bureau_units_parent_same_bureau") if
      foreign_key_exists?(:bureau_units, name: "fk_bureau_units_parent_same_bureau")
    remove_foreign_key(:agent_memberships, column: :approved_by_agent_id) if foreign_key_exists?(:agent_memberships, column: :approved_by_agent_id)
    remove_foreign_key(:agent_memberships, column: :granted_by_agent_id) if foreign_key_exists?(:agent_memberships, column: :granted_by_agent_id)
    remove_foreign_key(:agent_memberships, column: :revoked_by_agent_id) if foreign_key_exists?(:agent_memberships, column: :revoked_by_agent_id)

    add_foreign_key(
      :agent_memberships,
      :bureau_units,
      column: %i[bureau_unit_id bureau_id],
      primary_key: %i[id bureau_id],
      validate: false,
      name: "fk_agent_memberships_unit_same_bureau",
    )
    add_foreign_key(
      :bureau_units,
      :bureau_units,
      column: %i[parent_id bureau_id],
      primary_key: %i[id bureau_id],
      validate: false,
      name: "fk_bureau_units_parent_same_bureau",
    )
    add_foreign_key :agent_memberships, :agents, column: :approved_by_agent_id, validate: false
    add_foreign_key :agent_memberships, :agents, column: :granted_by_agent_id, validate: false
    add_foreign_key :agent_memberships, :agents, column: :revoked_by_agent_id, validate: false
  end
end
