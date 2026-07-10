# frozen_string_literal: true

class AddOnDeleteActionsToVisitorPrincipalForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:visitor_withdrawal_flow_events, column: :visitor_id) if foreign_key_exists?(:visitor_withdrawal_flow_events, column: :visitor_id)
    remove_foreign_key(:visitor_withdrawal_flow_events, column: :from_status_id) if foreign_key_exists?(:visitor_withdrawal_flow_events, column: :from_status_id)
    remove_foreign_key(:visitor_withdrawal_flow_events, column: :to_status_id) if foreign_key_exists?(:visitor_withdrawal_flow_events, column: :to_status_id)

    add_foreign_key :visitor_withdrawal_flow_events, :visitors, column: :visitor_id, on_delete: :cascade, validate: false
    add_foreign_key :visitor_withdrawal_flow_events, :visitor_withdrawal_flow_statuses, column: :from_status_id, on_delete: :restrict, validate: false
    add_foreign_key :visitor_withdrawal_flow_events, :visitor_withdrawal_flow_statuses, column: :to_status_id, on_delete: :restrict, validate: false
  end

  def down
    remove_foreign_key(:visitor_withdrawal_flow_events, column: :visitor_id) if foreign_key_exists?(:visitor_withdrawal_flow_events, column: :visitor_id)
    remove_foreign_key(:visitor_withdrawal_flow_events, column: :from_status_id) if foreign_key_exists?(:visitor_withdrawal_flow_events, column: :from_status_id)
    remove_foreign_key(:visitor_withdrawal_flow_events, column: :to_status_id) if foreign_key_exists?(:visitor_withdrawal_flow_events, column: :to_status_id)

    add_foreign_key :visitor_withdrawal_flow_events, :visitors, column: :visitor_id, validate: false
    add_foreign_key :visitor_withdrawal_flow_events, :visitor_withdrawal_flow_statuses, column: :from_status_id, validate: false
    add_foreign_key :visitor_withdrawal_flow_events, :visitor_withdrawal_flow_statuses, column: :to_status_id, validate: false
  end
end
