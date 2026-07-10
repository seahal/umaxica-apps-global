# frozen_string_literal: true

class AddAssignedByActorIndexToHandleAssignments < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :handle_assignments, :assigned_by_actor_id, algorithm: :concurrently
  end
end
