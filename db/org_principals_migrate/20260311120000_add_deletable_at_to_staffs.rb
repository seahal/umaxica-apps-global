# frozen_string_literal: true

class AddDeletableAtToStaffs < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(
        :staffs,
        :deletable_at,
        :datetime,
        null: false,
        default: -> { "'infinity'" },
      ) unless column_exists?(:staffs, :deletable_at)
    end

    add_index(:staffs, :deletable_at, algorithm: :concurrently) unless index_exists?(:staffs, :deletable_at)
  end

  def down
    remove_index(:staffs, column: :deletable_at, algorithm: :concurrently) if index_exists?(:staffs, :deletable_at)
    remove_column(:staffs, :deletable_at) if column_exists?(:staffs, :deletable_at)
  end
end
