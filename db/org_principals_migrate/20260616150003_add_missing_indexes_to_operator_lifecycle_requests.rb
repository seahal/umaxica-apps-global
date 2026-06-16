# frozen_string_literal: true

class AddMissingIndexesToOperatorLifecycleRequests < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :operator_lifecycle_requests, :executed_by_operator_id, algorithm: :concurrently
    add_index :operator_lifecycle_requests, :rejected_by_operator_id, algorithm: :concurrently
  end
end
