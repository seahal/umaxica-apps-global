# frozen_string_literal: true

# Second step of the users.purged_at parity fix. Validating the NOT VALID
# check first lets Postgres skip the full-table scan when the column is
# flipped to NOT NULL, after which the now-redundant check is dropped.
class ValidateUsersPurgedAtNotNull < ActiveRecord::Migration[8.2]
  CONSTRAINT_NAME = "chk_users_purged_at_not_null"

  def up
    validate_check_constraint :users, name: CONSTRAINT_NAME
    safety_assured { change_column_null :users, :purged_at, false }
    remove_check_constraint :users, name: CONSTRAINT_NAME, if_exists: true
  end

  def down
    add_check_constraint :users, "purged_at IS NOT NULL",
                         name: CONSTRAINT_NAME, validate: false, if_not_exists: true
    safety_assured { change_column_null :users, :purged_at, true }
  end
end
