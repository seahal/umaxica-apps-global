# frozen_string_literal: true

class RenameOrganizationsToDepartments < ActiveRecord::Migration[8.2]
  def change
    # Rename organization_statuses table to department_statuses
    if table_exists?(:organization_statuses) && !table_exists?(:department_statuses)
      safety_assured do
        rename_table(:organization_statuses, :department_statuses)
      end
    end

    # Rename organizations or workspaces table to departments
    # (Check both since workspaces was previously organizations)
    if table_exists?(:organizations) && !table_exists?(:departments)
      safety_assured do
        rename_table(:organizations, :departments)
      end
    elsif table_exists?(:workspaces) && !table_exists?(:departments)
      safety_assured do
        rename_table(:workspaces, :departments)
      end
    end

    # Rename the foreign key column in departments table
    return unless table_exists?(:departments) && column_exists?(:departments, :organization_status_id)

    safety_assured do
      rename_column(:departments, :organization_status_id, :department_status_id)
    end

  end
end
