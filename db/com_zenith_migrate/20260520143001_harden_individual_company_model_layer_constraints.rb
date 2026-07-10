# frozen_string_literal: true

class HardenIndividualCompanyModelLayerConstraints < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(:individuals, :visitor_identity_id, unique: true, name: "idx_individuals_one_per_visitor_identity",
                                                     algorithm: :concurrently) unless
      index_exists?(:individuals, :visitor_identity_id, name: "idx_individuals_one_per_visitor_identity")
    add_index(:company_units, %i(id company_id), unique: true, name: "idx_company_units_id_company",
                                                     algorithm: :concurrently) unless
      index_exists?(:company_units, %i(id company_id), name: "idx_company_units_id_company")

    unless foreign_key_exists?(:company_units, name: "fk_company_units_parent_same_company")
      add_foreign_key(
        :company_units,
        :company_units,
        column: %i(parent_id company_id),
        primary_key: %i(id company_id),
        validate: false,
        name: "fk_company_units_parent_same_company",
      )
    end
    unless foreign_key_exists?(:individual_memberships, name: "fk_individual_memberships_unit_same_company")
      add_foreign_key(
        :individual_memberships,
        :company_units,
        column: %i(company_unit_id company_id),
        primary_key: %i(id company_id),
        validate: false,
        name: "fk_individual_memberships_unit_same_company",
      )
    end

    return if check_constraint_exists?(:company_unit_closures, name: "chk_company_unit_closures_depth_matches_self")

    add_check_constraint(
      :company_unit_closures,
      "(ancestor_id = descendant_id AND depth = 0) OR (ancestor_id <> descendant_id AND depth > 0)",
      name: "chk_company_unit_closures_depth_matches_self",
      validate: false,
    )
  end

  def down
    remove_check_constraint(:company_unit_closures, name: "chk_company_unit_closures_depth_matches_self") if
      check_constraint_exists?(:company_unit_closures, name: "chk_company_unit_closures_depth_matches_self")
    remove_foreign_key(:individual_memberships, name: "fk_individual_memberships_unit_same_company") if
      foreign_key_exists?(:individual_memberships, name: "fk_individual_memberships_unit_same_company")
    remove_foreign_key(:company_units, name: "fk_company_units_parent_same_company") if
      foreign_key_exists?(:company_units, name: "fk_company_units_parent_same_company")
    remove_index(:company_units, name: "idx_company_units_id_company", algorithm: :concurrently) if
      index_exists?(:company_units, name: "idx_company_units_id_company")
    remove_index(:individuals, name: "idx_individuals_one_per_visitor_identity", algorithm: :concurrently) if
      index_exists?(:individuals, name: "idx_individuals_one_per_visitor_identity")
  end
end
