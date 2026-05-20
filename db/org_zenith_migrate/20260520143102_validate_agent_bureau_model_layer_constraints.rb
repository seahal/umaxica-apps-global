# frozen_string_literal: true

class ValidateAgentBureauModelLayerConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:bureau_units, name: "fk_bureau_units_parent_same_bureau")
    validate_foreign_key(:agent_memberships, name: "fk_agent_memberships_unit_same_bureau")
    validate_check_constraint(:bureau_unit_closures, name: "chk_bureau_unit_closures_depth_matches_self")
  end

  def down
    # Validation status is intentionally not reversed. The preceding hardening
    # migration owns constraint removal on rollback.
  end
end
