# frozen_string_literal: true

class RenameOrgRpTables < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      rename_table(:staff_accounts, :operator_accounts)
      rename_table(:staff_personnel_statuses, :operator_subject_statuses)
      rename_table(:staff_personnels, :operator_subjects)
    end
  end
end
