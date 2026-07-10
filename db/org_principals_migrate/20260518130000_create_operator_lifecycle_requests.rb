# frozen_string_literal: true

class CreateOperatorLifecycleRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :operator_lifecycle_requests do |t|
      t.string :public_id, limit: 21, null: false
      t.string :action, null: false
      t.string :status, null: false, default: "pending"
      t.bigint :target_operator_id
      t.string :target_email
      t.bigint :organization_id
      t.bigint :role_id, null: false, default: 0
      t.bigint :requested_by_operator_id, null: false
      t.bigint :approved_by_operator_id
      t.bigint :rejected_by_operator_id
      t.bigint :executed_by_operator_id
      t.bigint :invitation_id
      t.text :reason
      t.text :rejection_reason
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :executed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :operator_lifecycle_requests, :public_id, unique: true
    add_index :operator_lifecycle_requests, :status
    add_index :operator_lifecycle_requests, :action
    add_index :operator_lifecycle_requests, :target_operator_id
    add_index :operator_lifecycle_requests, :target_email
    add_index :operator_lifecycle_requests, :requested_by_operator_id
    add_index :operator_lifecycle_requests, :approved_by_operator_id
  end
end
