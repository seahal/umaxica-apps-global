# frozen_string_literal: true

class AddShreddableAtToAvatars < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(:avatars, :shreddable_at, :datetime, null: false, default: -> { "'infinity'" })
    end
    add_index(:avatars, :shreddable_at, algorithm: :concurrently)
  end

  def down
    remove_index(:avatars, :shreddable_at, algorithm: :concurrently) if index_exists?(:avatars, :shreddable_at)
    remove_column(:avatars, :shreddable_at) if column_exists?(:avatars, :shreddable_at)
  end
end
