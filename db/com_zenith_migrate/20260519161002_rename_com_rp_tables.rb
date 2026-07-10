# frozen_string_literal: true

class RenameComRpTables < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      rename_table(:client_accounts, :visitor_accounts)
      rename_table(:client_visitor_statuses, :visitor_subject_statuses)
      rename_table(:client_visitors, :visitor_subjects)
    end
  end
end
