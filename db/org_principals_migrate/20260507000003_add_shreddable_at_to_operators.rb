# frozen_string_literal: true

class AddShreddableAtToOperators < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(:operators, :shreddable_at, :datetime, null: false, default: -> { "'infinity'" })
    end
    add_index(:operators, :shreddable_at, algorithm: :concurrently)
  end

  def down
    remove_index(:operators, :shreddable_at, algorithm: :concurrently) if index_exists?(:operators, :shreddable_at)
    remove_column(:operators, :shreddable_at) if column_exists?(:operators, :shreddable_at)
  end
end
