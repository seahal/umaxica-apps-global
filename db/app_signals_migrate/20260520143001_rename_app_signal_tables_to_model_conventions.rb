# frozen_string_literal: true

class RenameAppSignalTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :user_notifications, :client_notification_records
  end

  def down
    rename_table_strict :client_notification_records, :user_notifications
  end
end
