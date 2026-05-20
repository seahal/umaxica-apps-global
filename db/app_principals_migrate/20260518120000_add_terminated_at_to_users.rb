# frozen_string_literal: true

class AddTerminatedAtToUsers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :users, :terminated_at, :datetime unless column_exists?(:users, :terminated_at)
    add_index :users, :terminated_at, where: "terminated_at IS NOT NULL", if_not_exists: true, algorithm: :concurrently
  end
end
