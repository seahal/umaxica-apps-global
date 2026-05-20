# frozen_string_literal: true

class AddPrimaryKeyToUserIdentityOneTimePasswords < ActiveRecord::Migration[8.2]
  def up
    execute(<<~SQL.squish)
      ALTER TABLE user_identity_one_time_passwords
      ADD COLUMN id uuid DEFAULT #{uuid_default_function}() PRIMARY KEY;
    SQL
  end

  def down
    # Remove the primary key column on rollback
    remove_column(:user_identity_one_time_passwords, :id)
  end

  private

  def uuid_default_function
    select_value("SELECT to_regproc('uuidv7')").present? ? "uuidv7" : "gen_random_uuid"
  end
end
