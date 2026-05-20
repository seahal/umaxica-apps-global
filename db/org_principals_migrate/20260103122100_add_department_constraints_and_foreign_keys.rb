# frozen_string_literal: true

class AddDepartmentConstraintsAndForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Add missing columns to departments table
    unless column_exists?(:departments, :department_status_id)
      add_column(:departments, :department_status_id, :string, limit: 255, null: false, default: "NEYO")
    end
    add_column(:departments, :parent_id, :bigint) unless column_exists?(:departments, :parent_id)
    add_column(:departments, :workspace_id, :bigint) unless column_exists?(:departments, :workspace_id)

    # Add indexes
    add_index(:departments, :department_status_id, if_not_exists: true, algorithm: :concurrently)
    add_index(:departments, :parent_id, if_not_exists: true, algorithm: :concurrently)
    add_index(:departments, :workspace_id, if_not_exists: true, algorithm: :concurrently)

    # Add unique index for department_status_id + parent_id
    add_index(
      :departments, [:department_status_id, :parent_id],
      unique: true,
      name: "index_departments_on_department_status_id_and_parent_id",
      if_not_exists: true,
      algorithm: :concurrently,
    )

    # Add foreign keys for Department relationships
    add_foreign_key(
      :departments, :departments, column: :parent_id, on_delete: :restrict, if_not_exists: true,
                                  validate: false,
    )
    add_foreign_key(
      :departments, :department_statuses,
      column: :department_status_id,
      primary_key: :id,
      on_delete: :restrict,
      if_not_exists: true,
      validate: false,
    )
    add_foreign_key(:departments, :workspaces, on_delete: :restrict, if_not_exists: true, validate: false)
  end
end
