# frozen_string_literal: true

# Migration to remove redundant indexes from principal tables
# This resolves RedundantIndexChecker warnings
class RemoveRedundantPrincipalIndexes < ActiveRecord::Migration[7.1]
  def change
    # UserClient: index_user_clients_on_user_id is redundant
    remove_index(:user_clients, column: :user_id, name: "index_user_clients_on_user_id", if_exists: true)
  end
end
