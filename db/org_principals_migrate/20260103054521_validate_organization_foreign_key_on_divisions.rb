# frozen_string_literal: true

class ValidateOrganizationForeignKeyOnDivisions < ActiveRecord::Migration[8.2]
  def change
    # Skip this migration - organizations table doesn't exist (was renamed to departments)
    # This migration is obsolete
    nil
  end
end
