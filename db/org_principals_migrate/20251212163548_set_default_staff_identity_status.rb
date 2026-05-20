# frozen_string_literal: true

class SetDefaultStaffIdentityStatus < ActiveRecord::Migration[8.2]
  def change
    # Update existing null values to NONE
    reversible do |dir|
      dir.up do
        execute("UPDATE staffs SET staff_identity_status_id = 'NONE' WHERE staff_identity_status_id IS NULL")
      end
    end

    # Add default value to column
    change_column_default(:staffs, :staff_identity_status_id, from: nil, to: "NONE")
  end
end
