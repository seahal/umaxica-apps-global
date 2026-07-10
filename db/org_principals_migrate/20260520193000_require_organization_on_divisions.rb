# frozen_string_literal: true

class RequireOrganizationOnDivisions < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      remove_foreign_key(:divisions, :organizations) if foreign_key_exists?(:divisions, :organizations)
      change_column_null(:divisions, :organization_id, false)
      add_foreign_key(:divisions, :organizations, column: :organization_id)
    end
  end

  def down
    safety_assured do
      remove_foreign_key(:divisions, :organizations) if foreign_key_exists?(:divisions, :organizations)
      change_column_null(:divisions, :organization_id, true)
      add_foreign_key(:divisions, :organizations, column: :organization_id, on_delete: :nullify)
    end
  end
end
