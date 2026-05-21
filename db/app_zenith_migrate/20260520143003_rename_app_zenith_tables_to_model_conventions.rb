# frozen_string_literal: true

class RenameAppZenithTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :client_profile_statuses, :visitor_account_statuses
  end

  def down
    rename_table_strict :visitor_account_statuses, :client_profile_statuses
  end
end
