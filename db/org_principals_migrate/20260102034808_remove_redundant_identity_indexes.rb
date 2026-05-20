# frozen_string_literal: true

class RemoveRedundantIdentityIndexes < ActiveRecord::Migration[8.2]
  def change
    # Remove redundant index on user_clients.user_id (covered by composite index)
    remove_index(:user_clients, :user_id, if_exists: true)

    # Remove redundant index on staff_operators.staff_id (covered by composite index)
    remove_index(:staff_operators, :staff_id, if_exists: true)

    # Remove redundant index on divisions.parent_id (covered by unique index)
    remove_index(:divisions, :parent_id, if_exists: true)

    # Remove redundant index on departments.parent_id (covered by unique index)
    remove_index(:departments, :parent_id, if_exists: true)
  end
end
