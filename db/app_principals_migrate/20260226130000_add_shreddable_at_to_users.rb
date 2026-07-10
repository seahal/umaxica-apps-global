# frozen_string_literal: true

class AddShreddableAtToUsers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(:users, :shreddable_at, :datetime, null: false, default: -> { "'infinity'" })
    end
    add_index(:users, :shreddable_at, algorithm: :concurrently)
  end

  def down
    remove_index(:users, :shreddable_at, algorithm: :concurrently)
    remove_column(:users, :shreddable_at)
  end
end
