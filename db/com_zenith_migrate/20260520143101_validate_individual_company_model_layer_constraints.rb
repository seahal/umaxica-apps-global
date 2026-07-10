# frozen_string_literal: true

class ValidateIndividualCompanyModelLayerConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:company_units, name: "fk_company_units_parent_same_company")
    validate_foreign_key(:individual_memberships, name: "fk_individual_memberships_unit_same_company")
    validate_check_constraint(:company_unit_closures, name: "chk_company_unit_closures_depth_matches_self")
  end

  def down
    # Validation status is intentionally not reversed. The preceding hardening
    # migration owns constraint removal on rollback.
  end
end
