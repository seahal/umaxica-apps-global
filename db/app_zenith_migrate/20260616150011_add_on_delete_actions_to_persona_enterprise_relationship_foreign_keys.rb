# frozen_string_literal: true

class AddOnDeleteActionsToPersonaEnterpriseRelationshipForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise") if
      foreign_key_exists?(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise")
    remove_foreign_key(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise") if
      foreign_key_exists?(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise")
    remove_foreign_key(:persona_memberships, column: :approved_by_persona_id) if foreign_key_exists?(:persona_memberships, column: :approved_by_persona_id)
    remove_foreign_key(:persona_memberships, column: :granted_by_persona_id) if foreign_key_exists?(:persona_memberships, column: :granted_by_persona_id)
    remove_foreign_key(:persona_memberships, column: :revoked_by_persona_id) if foreign_key_exists?(:persona_memberships, column: :revoked_by_persona_id)

    add_foreign_key(
      :enterprise_units,
      :enterprise_units,
      column: %i[parent_id enterprise_id],
      primary_key: %i[id enterprise_id],
      on_delete: :restrict,
      validate: false,
      name: "fk_enterprise_units_parent_same_enterprise",
    )
    add_foreign_key(
      :persona_memberships,
      :enterprise_units,
      column: %i[enterprise_unit_id enterprise_id],
      primary_key: %i[id enterprise_id],
      on_delete: :restrict,
      validate: false,
      name: "fk_persona_memberships_unit_same_enterprise",
    )
    add_foreign_key :persona_memberships, :personas, column: :approved_by_persona_id, on_delete: :nullify, validate: false
    add_foreign_key :persona_memberships, :personas, column: :granted_by_persona_id, on_delete: :nullify, validate: false
    add_foreign_key :persona_memberships, :personas, column: :revoked_by_persona_id, on_delete: :nullify, validate: false
  end

  def down
    remove_foreign_key(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise") if
      foreign_key_exists?(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise")
    remove_foreign_key(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise") if
      foreign_key_exists?(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise")
    remove_foreign_key(:persona_memberships, column: :approved_by_persona_id) if foreign_key_exists?(:persona_memberships, column: :approved_by_persona_id)
    remove_foreign_key(:persona_memberships, column: :granted_by_persona_id) if foreign_key_exists?(:persona_memberships, column: :granted_by_persona_id)
    remove_foreign_key(:persona_memberships, column: :revoked_by_persona_id) if foreign_key_exists?(:persona_memberships, column: :revoked_by_persona_id)

    add_foreign_key(
      :enterprise_units,
      :enterprise_units,
      column: %i[parent_id enterprise_id],
      primary_key: %i[id enterprise_id],
      validate: false,
      name: "fk_enterprise_units_parent_same_enterprise",
    )
    add_foreign_key(
      :persona_memberships,
      :enterprise_units,
      column: %i[enterprise_unit_id enterprise_id],
      primary_key: %i[id enterprise_id],
      validate: false,
      name: "fk_persona_memberships_unit_same_enterprise",
    )
    add_foreign_key :persona_memberships, :personas, column: :approved_by_persona_id, validate: false
    add_foreign_key :persona_memberships, :personas, column: :granted_by_persona_id, validate: false
    add_foreign_key :persona_memberships, :personas, column: :revoked_by_persona_id, validate: false
  end
end
