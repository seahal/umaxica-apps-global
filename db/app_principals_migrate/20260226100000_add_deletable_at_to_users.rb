# frozen_string_literal: true

class AddDeletableAtToUsers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_column(:users, :deletable_at, :datetime) unless column_exists?(:users, :deletable_at)

    safety_assured do
      execute(<<~SQL.squish)
        UPDATE users
        SET deletable_at = scheduled_purge_at
        WHERE scheduled_purge_at IS NOT NULL
          AND deletable_at IS NULL
      SQL
    end

    add_index(
      :users, :deletable_at,
      where: "deletable_at IS NOT NULL",
      algorithm: :concurrently,
    ) unless index_exists?(:users, :deletable_at, where: "deletable_at IS NOT NULL")
  end

  def down
    remove_index(:users, column: :deletable_at, algorithm: :concurrently) if index_exists?(
      :users, :deletable_at,
      where: "deletable_at IS NOT NULL",
    )
    remove_column(:users, :deletable_at) if column_exists?(:users, :deletable_at)
  end
end
