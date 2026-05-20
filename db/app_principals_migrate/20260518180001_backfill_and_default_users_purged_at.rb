# frozen_string_literal: true

# users.purged_at originated from a rename of the nullable deletable_at column,
# so unlike visitors.purged_at / operators.purged_at it is currently nullable
# with no DB default. Retainable expects the Infinity sentinel and validates
# presence at the model layer only. This migration restores parity:
#   1. new writes default to Infinity (consistent with sibling surfaces)
#   2. legacy NULLs are backfilled to Infinity
#   3. a NOT VALID check is added so the follow-up migration can flip the
#      column to NOT NULL without a long table scan / lock.
class BackfillAndDefaultUsersPurgedAt < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CONSTRAINT_NAME = "chk_users_purged_at_not_null"

  def up
    change_column_default :users, :purged_at, -> { "'infinity'" }

    # Bounded single statement: only legacy rows from the deletable_at rename
    # path can be NULL; new rows already carry the Infinity sentinel.
    safety_assured do
      execute("UPDATE users SET purged_at = 'infinity' WHERE purged_at IS NULL")
    end

    add_check_constraint :users, "purged_at IS NOT NULL",
                         name: CONSTRAINT_NAME, validate: false, if_not_exists: true
  end

  def down
    remove_check_constraint :users, name: CONSTRAINT_NAME, if_exists: true
    change_column_default :users, :purged_at, nil
  end
end
