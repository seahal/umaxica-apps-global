# frozen_string_literal: true

class AddOnDeleteActionsToIndividualCompanyRelationshipForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:company_units, name: "fk_company_units_parent_same_company") if
      foreign_key_exists?(:company_units, name: "fk_company_units_parent_same_company")
    remove_foreign_key(:individual_memberships, name: "fk_individual_memberships_unit_same_company") if
      foreign_key_exists?(:individual_memberships, name: "fk_individual_memberships_unit_same_company")
    remove_foreign_key(:individual_memberships, column: :approved_by_individual_id) if foreign_key_exists?(:individual_memberships, column: :approved_by_individual_id)
    remove_foreign_key(:individual_memberships, column: :granted_by_individual_id) if foreign_key_exists?(:individual_memberships, column: :granted_by_individual_id)
    remove_foreign_key(:individual_memberships, column: :revoked_by_individual_id) if foreign_key_exists?(:individual_memberships, column: :revoked_by_individual_id)

    add_foreign_key(
      :company_units,
      :company_units,
      column: %i[parent_id company_id],
      primary_key: %i[id company_id],
      on_delete: :restrict,
      validate: false,
      name: "fk_company_units_parent_same_company",
    )
    add_foreign_key(
      :individual_memberships,
      :company_units,
      column: %i[company_unit_id company_id],
      primary_key: %i[id company_id],
      on_delete: :restrict,
      validate: false,
      name: "fk_individual_memberships_unit_same_company",
    )
    add_foreign_key :individual_memberships, :individuals, column: :approved_by_individual_id, on_delete: :nullify, validate: false
    add_foreign_key :individual_memberships, :individuals, column: :granted_by_individual_id, on_delete: :nullify, validate: false
    add_foreign_key :individual_memberships, :individuals, column: :revoked_by_individual_id, on_delete: :nullify, validate: false
  end

  def down
    remove_foreign_key(:company_units, name: "fk_company_units_parent_same_company") if
      foreign_key_exists?(:company_units, name: "fk_company_units_parent_same_company")
    remove_foreign_key(:individual_memberships, name: "fk_individual_memberships_unit_same_company") if
      foreign_key_exists?(:individual_memberships, name: "fk_individual_memberships_unit_same_company")
    remove_foreign_key(:individual_memberships, column: :approved_by_individual_id) if foreign_key_exists?(:individual_memberships, column: :approved_by_individual_id)
    remove_foreign_key(:individual_memberships, column: :granted_by_individual_id) if foreign_key_exists?(:individual_memberships, column: :granted_by_individual_id)
    remove_foreign_key(:individual_memberships, column: :revoked_by_individual_id) if foreign_key_exists?(:individual_memberships, column: :revoked_by_individual_id)

    add_foreign_key(
      :company_units,
      :company_units,
      column: %i[parent_id company_id],
      primary_key: %i[id company_id],
      validate: false,
      name: "fk_company_units_parent_same_company",
    )
    add_foreign_key(
      :individual_memberships,
      :company_units,
      column: %i[company_unit_id company_id],
      primary_key: %i[id company_id],
      validate: false,
      name: "fk_individual_memberships_unit_same_company",
    )
    add_foreign_key :individual_memberships, :individuals, column: :approved_by_individual_id, validate: false
    add_foreign_key :individual_memberships, :individuals, column: :granted_by_individual_id, validate: false
    add_foreign_key :individual_memberships, :individuals, column: :revoked_by_individual_id, validate: false
  end
end
