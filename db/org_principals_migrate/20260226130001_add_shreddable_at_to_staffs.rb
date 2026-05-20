# frozen_string_literal: true

class AddShreddableAtToStaffs < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(:staffs, :shreddable_at, :datetime, null: false, default: -> { "'infinity'" })
    end
    add_index(:staffs, :shreddable_at, algorithm: :concurrently)
  end

  def down
    remove_index(:staffs, :shreddable_at, algorithm: :concurrently)
    remove_column(:staffs, :shreddable_at)
  end
end
