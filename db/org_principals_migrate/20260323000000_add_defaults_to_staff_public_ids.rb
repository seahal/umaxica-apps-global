# frozen_string_literal: true

class AddDefaultsToStaffPublicIds < ActiveRecord::Migration[8.2]
  def up
    # Add default values to columns that were created without defaults
    # Only modify tables that still exist
    change_column_default(:staff_emails, :public_id, "") if table_exists?(:staff_emails)

    # staff_one_time_passwords table was dropped in migration 20260311130000
    # No action needed for this table
  end

  def down
    change_column_default(:staff_emails, :public_id, nil) if table_exists?(:staff_emails)
  end
end
