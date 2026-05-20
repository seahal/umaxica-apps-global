# frozen_string_literal: true

class AddForeignKeysToWorkspaceOrganizationDivision < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Add foreign keys for Workspace
    add_foreign_key(
      :workspaces, :workspace_statuses,
      column: :workspace_status_id,
      primary_key: :id,
      on_delete: :restrict,
      if_not_exists: true,
      validate: false,
    )

    # Add index for departments.workspace_id (if not exists, for FK performance)
    add_index(:departments, :workspace_id, if_not_exists: true, algorithm: :concurrently)

    # Add foreign keys for Organization (Removed as table renamed)

    # Add foreign keys for Division (Removed as table renamed)

    # Add foreign key from clients to divisions with nullify

    # Add foreign key from operators to departments with nullify
    add_foreign_key(
      :operators, :departments,
      on_delete: :nullify,
      if_not_exists: true,
      validate: false,
    )
  end
end
