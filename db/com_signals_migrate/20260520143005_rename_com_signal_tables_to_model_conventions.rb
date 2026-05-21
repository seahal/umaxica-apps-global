# frozen_string_literal: true

class RenameComSignalTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :visitor_notifications, :visitor_notification_records
  end

  def down
    rename_table_strict :visitor_notification_records, :visitor_notifications
  end
end
