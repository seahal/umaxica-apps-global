# frozen_string_literal: true

class RemoveRedundantChronicleIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:chronicle_visibilities, name: "index_chronicle_visibilities_on_chronicle_id", algorithm: :concurrently) if
      index_exists?(:chronicle_visibilities, name: "index_chronicle_visibilities_on_chronicle_id")
  end

  def down
    add_index(:chronicle_visibilities, :chronicle_id, name: "index_chronicle_visibilities_on_chronicle_id", algorithm: :concurrently) unless
      index_exists?(:chronicle_visibilities, name: "index_chronicle_visibilities_on_chronicle_id")
  end
end
