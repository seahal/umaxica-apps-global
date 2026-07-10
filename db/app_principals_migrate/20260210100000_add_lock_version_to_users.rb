# frozen_string_literal: true

class AddLockVersionToUsers < ActiveRecord::Migration[7.1]
  def up
    return if column_exists?(:users, :lock_version)

    add_column(:users, :lock_version, :integer)
    execute("UPDATE users SET lock_version = 0 WHERE lock_version IS NULL")
    change_column_default(:users, :lock_version, 0)
    change_column_null(:users, :lock_version, false)
  end

  def down
    remove_column(:users, :lock_version) if column_exists?(:users, :lock_version)
  end
end
