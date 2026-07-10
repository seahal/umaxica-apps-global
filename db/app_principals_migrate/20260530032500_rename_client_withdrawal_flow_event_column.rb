# frozen_string_literal: true

class RenameClientWithdrawalFlowEventColumn < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      rename_column :client_withdrawal_flow_events, :client_withdrawal_cycle_id, :client_withdrawal_flow_id
    end
  end
end
