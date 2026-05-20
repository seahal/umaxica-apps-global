# frozen_string_literal: true

class AddWorkspaceStatusToWorkspaces < ActiveRecord::Migration[8.2]
  def change
    # Skip - workspaces table doesn't exist (was renamed to departments)
    nil
  end
end
