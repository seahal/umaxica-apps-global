# frozen_string_literal: true

class RenameUserOrganizationsToUserWorkspaces < ActiveRecord::Migration[8.2]
  def change
    rename_table(:user_organizations, :user_workspaces)
    rename_column(:user_workspaces, :organization_id, :workspace_id)
  end
end
