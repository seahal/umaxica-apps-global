# frozen_string_literal: true

class RenameAppRpTables < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      rename_table(:user_accounts, :client_accounts)
      rename_table(:user_resident_statuses, :client_subject_statuses)
      rename_table(:user_residents, :client_subjects)
    end
  end
end
