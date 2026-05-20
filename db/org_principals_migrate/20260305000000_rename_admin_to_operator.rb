# frozen_string_literal: true

class RenameAdminToOperator < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      # Rename Columns (indexes are auto-renamed by Rails)
      rename_column(:staff_operators, :admin_id, :operator_id)
      rename_column(:organizations, :admin_id, :operator_id)
    end
  end
end
