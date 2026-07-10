# frozen_string_literal: true

class FixUserDefaultsAndConstraints < ActiveRecord::Migration[8.2]
  def change
    reversible do |dir|
      dir.up do
        change_column_default(
          :user_identity_one_time_passwords, :user_identity_one_time_password_status_id, from: "",
                                                                                         to: "NONE",
        )
        up_only {
          execute("UPDATE user_identity_one_time_passwords SET user_identity_one_time_password_status_id = 'NONE' WHERE user_identity_one_time_password_status_id = ''")
        }
      end
      dir.down do
        change_column_default(
          :user_identity_one_time_passwords, :user_identity_one_time_password_status_id,
          from: "NONE", to: "",
        )
      end
    end
  end
end
