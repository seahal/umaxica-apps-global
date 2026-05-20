# frozen_string_literal: true

class ValidateWorkspaceDepartmentAndParentForeignKeys < ActiveRecord::Migration[8.2]
  def change
    # Skip - workspaces table doesn't exist (was renamed to departments)
    nil
  end
end
