# frozen_string_literal: true

class RenameChronicleTablesToModelConventions < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :staff_chronicle_events, :operator_chronicle_events
    rename_table_strict :staff_chronicle_levels, :operator_chronicle_levels
    rename_table_strict :staff_chronicles, :operator_chronicles
    rename_table_strict :user_chronicle_events, :client_chronicle_events
    rename_table_strict :user_chronicle_levels, :client_chronicle_levels
    rename_table_strict :user_chronicles, :client_chronicles
  end

  def down
    rename_table_strict :client_chronicles, :user_chronicles
    rename_table_strict :client_chronicle_levels, :user_chronicle_levels
    rename_table_strict :client_chronicle_events, :user_chronicle_events
    rename_table_strict :operator_chronicles, :staff_chronicles
    rename_table_strict :operator_chronicle_levels, :staff_chronicle_levels
    rename_table_strict :operator_chronicle_events, :staff_chronicle_events
  end
end
