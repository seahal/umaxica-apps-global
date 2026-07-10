# frozen_string_literal: true

class AddRequestedByOperatorFkToOperatorLifecycleRequests < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key :operator_lifecycle_requests, :operators, column: :requested_by_operator_id,
                    on_delete: :restrict, validate: false
  end
end
