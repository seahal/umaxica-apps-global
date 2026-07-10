# frozen_string_literal: true

class RenameOrganizationsToWorkspaces < ActiveRecord::Migration[8.2]
  def up
    rename_table(:organizations, :workspaces)
  end

  def down
    rename_table(:workspaces, :organizations)
  end
end
