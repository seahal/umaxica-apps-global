# frozen_string_literal: true

class AddOnDeleteActionsToClientPrincipalForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:client_withdrawal_flow_events, column: :client_id) if foreign_key_exists?(:client_withdrawal_flow_events, column: :client_id)
    remove_foreign_key(:client_withdrawal_flow_events, column: :from_status_id) if foreign_key_exists?(:client_withdrawal_flow_events, column: :from_status_id)
    remove_foreign_key(:client_withdrawal_flow_events, column: :to_status_id) if foreign_key_exists?(:client_withdrawal_flow_events, column: :to_status_id)

    add_foreign_key :client_withdrawal_flow_events, :clients, column: :client_id, on_delete: :cascade, validate: false
    add_foreign_key :client_withdrawal_flow_events, :client_withdrawal_flow_statuses, column: :from_status_id, on_delete: :restrict, validate: false
    add_foreign_key :client_withdrawal_flow_events, :client_withdrawal_flow_statuses, column: :to_status_id, on_delete: :restrict, validate: false
  end

  def down
    remove_foreign_key(:client_withdrawal_flow_events, column: :client_id) if foreign_key_exists?(:client_withdrawal_flow_events, column: :client_id)
    remove_foreign_key(:client_withdrawal_flow_events, column: :from_status_id) if foreign_key_exists?(:client_withdrawal_flow_events, column: :from_status_id)
    remove_foreign_key(:client_withdrawal_flow_events, column: :to_status_id) if foreign_key_exists?(:client_withdrawal_flow_events, column: :to_status_id)

    add_foreign_key :client_withdrawal_flow_events, :clients, column: :client_id, validate: false
    add_foreign_key :client_withdrawal_flow_events, :client_withdrawal_flow_statuses, column: :from_status_id, validate: false
    add_foreign_key :client_withdrawal_flow_events, :client_withdrawal_flow_statuses, column: :to_status_id, validate: false
  end
end
