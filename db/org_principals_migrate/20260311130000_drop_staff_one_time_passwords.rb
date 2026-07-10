# frozen_string_literal: true

class DropStaffOneTimePasswords < ActiveRecord::Migration[8.2]
  def up
    drop_table(:staff_one_time_passwords, if_exists: true)
    drop_table(:staff_one_time_password_statuses, if_exists: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
