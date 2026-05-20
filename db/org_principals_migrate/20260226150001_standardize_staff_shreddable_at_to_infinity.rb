# frozen_string_literal: true

class StandardizeStaffShreddableAtToInfinity < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE staffs
        SET shreddable_at = 'infinity'
        WHERE shreddable_at IS NULL
      SQL

      change_column_null(:staffs, :shreddable_at, false)
    end

    change_column_default(:staffs, :shreddable_at, -> { "'infinity'" })
    add_index(:staffs, :shreddable_at, algorithm: :concurrently) unless index_exists?(:staffs, :shreddable_at)
  end

  def down
    change_column_null(:staffs, :shreddable_at, true)
    change_column_default(:staffs, :shreddable_at, nil)
  end
end
