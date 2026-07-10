# frozen_string_literal: true

class StandardizeUserDeletionWindowsToInfinity < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE users
        SET deletable_at = 'infinity'
        WHERE deletable_at IS NULL
      SQL

      execute(<<~SQL.squish)
        UPDATE users
        SET shreddable_at = 'infinity'
        WHERE shreddable_at IS NULL
      SQL
    end

    change_column_default(:users, :deletable_at, -> { "'infinity'" })
    change_column_default(:users, :shreddable_at, -> { "'infinity'" })

    safety_assured do
      change_column_null(:users, :deletable_at, false)
      change_column_null(:users, :shreddable_at, false)
    end

    if index_exists?(:users, :deletable_at, where: "deletable_at IS NOT NULL")
      remove_index(:users, column: :deletable_at, algorithm: :concurrently)
      add_index(:users, :deletable_at, algorithm: :concurrently) unless index_exists?(:users, :deletable_at)
    elsif !index_exists?(:users, :deletable_at)
      add_index(:users, :deletable_at, algorithm: :concurrently)
    end

    add_index(:users, :shreddable_at, algorithm: :concurrently) unless index_exists?(:users, :shreddable_at)
  end

  def down
    if index_exists?(:users, :deletable_at) && !index_exists?(:users, :deletable_at, where: "deletable_at IS NOT NULL")
      remove_index(:users, column: :deletable_at, algorithm: :concurrently)
      add_index(:users, :deletable_at, where: "deletable_at IS NOT NULL", algorithm: :concurrently)
    end

    change_column_null(:users, :deletable_at, true)
    change_column_default(:users, :deletable_at, nil)
  end
end
