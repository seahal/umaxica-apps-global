# frozen_string_literal: true

class ValidatePersonaEnterpriseModelLayerConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:enterprise_units, name: "fk_enterprise_units_parent_same_enterprise")
    validate_foreign_key(:persona_memberships, name: "fk_persona_memberships_unit_same_enterprise")
    validate_check_constraint(:enterprise_unit_closures, name: "chk_enterprise_unit_closures_depth_matches_self")
  end

  def down
    # Validation status is intentionally not reversed. The preceding hardening
    # migration owns constraint removal on rollback.
  end
end
