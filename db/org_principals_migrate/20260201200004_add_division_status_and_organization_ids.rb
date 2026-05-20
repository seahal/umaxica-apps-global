# frozen_string_literal: true

# Migration to add division_status_id and organization_id columns to divisions table
# This resolves ForeignKeyTypeChecker warnings for division associations
class AddDivisionStatusAndOrganizationIds < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column(:divisions, :division_status_id, :string)
    add_column(:divisions, :organization_id, :bigint)

    add_foreign_key(
      :divisions, :division_statuses,
      column: :division_status_id,
      on_delete: :restrict,
      validate: false,
    )
    add_foreign_key(
      :divisions, :organizations,
      column: :organization_id,
      on_delete: :restrict,
      validate: false,
    )

    add_index(
      :divisions, :division_status_id,
      name: "index_divisions_on_division_status_id",
      algorithm: :concurrently,
    )
    add_index(
      :divisions, :organization_id,
      name: "index_divisions_on_organization_id",
      algorithm: :concurrently,
    )
  end
end
