# frozen_string_literal: true

class RenameClientWithdrawalFlowTables < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    client_withdrawal_cycles: :client_withdrawal_flows,
    client_withdrawal_cycle_statuses: :client_withdrawal_flow_statuses,
    client_withdrawal_cycle_events: :client_withdrawal_flow_events,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
