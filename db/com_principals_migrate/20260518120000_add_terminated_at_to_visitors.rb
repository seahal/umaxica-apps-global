# frozen_string_literal: true

class AddTerminatedAtToVisitors < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :visitors, :terminated_at, :datetime unless column_exists?(:visitors, :terminated_at)
    add_index :visitors, :terminated_at, where: "terminated_at IS NOT NULL", if_not_exists: true, algorithm: :concurrently
  end
end
