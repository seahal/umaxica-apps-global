# frozen_string_literal: true

class AllowNullForUserSecretLastUsedAt < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      # First, allow NULL and remove default value
      change_column_default(:user_secrets, :last_used_at, from: -Float::INFINITY, to: nil)
      change_column_null(:user_secrets, :last_used_at, true)

      # Then update existing -Infinity values to NULL
      execute(<<~SQL.squish)
        UPDATE user_secrets
        SET last_used_at = NULL
        WHERE last_used_at = '-infinity'::timestamp
      SQL
    end
  end

  def down
    # Restore NOT NULL constraint and default value
    change_column_null(:user_secrets, :last_used_at, false, -Float::INFINITY)
    change_column_default(:user_secrets, :last_used_at, from: nil, to: -Float::INFINITY)

    # Restore NULL values to -Infinity
    execute(<<~SQL.squish)
      UPDATE user_secrets
      SET last_used_at = '-infinity'::timestamp
      WHERE last_used_at IS NULL
    SQL
  end
end
