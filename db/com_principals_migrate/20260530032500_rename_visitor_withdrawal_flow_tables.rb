# frozen_string_literal: true

class RenameVisitorWithdrawalFlowTables < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    visitor_withdrawal_cycles: :visitor_withdrawal_flows,
    visitor_withdrawal_cycle_statuses: :visitor_withdrawal_flow_statuses,
    visitor_withdrawal_cycle_events: :visitor_withdrawal_flow_events,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
    safety_assured do
      rename_column :visitor_withdrawal_flow_events, :visitor_withdrawal_cycle_id, :visitor_withdrawal_flow_id
    end
  end

  def down
    safety_assured do
      rename_column :visitor_withdrawal_flow_events, :visitor_withdrawal_flow_id, :visitor_withdrawal_cycle_id
    end
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
