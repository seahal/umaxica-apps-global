# frozen_string_literal: true

class AddShreddableAtToMembers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(:members, :shreddable_at, :datetime, null: false, default: -> { "'infinity'" })
    end
    add_index(:members, :shreddable_at, algorithm: :concurrently)
  end

  def down
    remove_index(:members, :shreddable_at, algorithm: :concurrently) if index_exists?(:members, :shreddable_at)
    remove_column(:members, :shreddable_at) if column_exists?(:members, :shreddable_at)
  end
end
