# frozen_string_literal: true

class RenameOrgSignalTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :staff_notifications, :operator_notification_records
  end

  def down
    rename_table_strict :operator_notification_records, :staff_notifications
  end
end
