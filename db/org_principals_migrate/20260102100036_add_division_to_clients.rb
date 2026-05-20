# frozen_string_literal: true

class AddDivisionToClients < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    return unless table_exists?(:clients)

    if column_exists?(:clients, :division_id)
      add_index(:clients, :division_id, algorithm: :concurrently) unless index_exists?(:clients, :division_id)
    else
      add_reference(:clients, :division, type: :bigint, index: { algorithm: :concurrently })
    end
  end
end
