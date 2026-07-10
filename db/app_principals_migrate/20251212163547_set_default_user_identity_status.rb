# frozen_string_literal: true

class SetDefaultUserIdentityStatus < ActiveRecord::Migration[8.2]
  def change
    # Update existing null values to NONE
    reversible do |dir|
      dir.up do
        execute("UPDATE users SET user_identity_status_id = 'NONE' WHERE user_identity_status_id IS NULL")
      end
    end

    # Add default value to column
    change_column_default(:users, :user_identity_status_id, from: nil, to: "NONE")
  end
end
