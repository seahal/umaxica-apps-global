# frozen_string_literal: true

class AddLockVersionToStaffs < ActiveRecord::Migration[7.1]
  def up
    return if column_exists?(:staffs, :lock_version)

    add_column(:staffs, :lock_version, :integer)
    safety_assured do
      execute("UPDATE staffs SET lock_version = 0 WHERE lock_version IS NULL")
      change_column_default(:staffs, :lock_version, 0)
      change_column_null(:staffs, :lock_version, false)
    end
  end

  def down
    remove_column(:staffs, :lock_version) if column_exists?(:staffs, :lock_version)
  end
end
