# frozen_string_literal: true

class AddWorkspaceToDepartments < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Skip this migration - workspaces table doesn't exist (was renamed to departments)
    # This migration is obsolete
    nil
  end
end
