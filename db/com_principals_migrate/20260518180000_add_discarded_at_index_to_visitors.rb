# frozen_string_literal: true

# Retainable keeps discarded_at NOT NULL with an Infinity sentinel and filters
# liveness via `where('discarded_at > ?', Time.current)`. A plain btree index is
# required for that range scan; a partial `WHERE IS NOT NULL` index would be
# useless because the column is never NULL.
class AddDiscardedAtIndexToVisitors < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  INDEX_NAME = "index_visitors_on_discarded_at"

  def up
    add_index :visitors, :discarded_at, name: INDEX_NAME,
                                        algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :visitors, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
