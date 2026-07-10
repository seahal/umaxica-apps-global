# frozen_string_literal: true

# Removing lower(code) unique indexes since:
# 1. citext columns are already case-insensitive
# 2. We have regular unique index on code column
# 3. database_consistency checker cannot match lower(code) index with Rails validators
class RemoveLowerCodeIndexesOperator < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # Find all lower_code indexes and remove them
      indexes = connection.select_all(<<~SQL.squish)
        SELECT indexname FROM pg_indexes#{" "}
        WHERE schemaname = 'public'#{" "}
        AND indexname LIKE '%_on_lower_code'
      SQL

      indexes.each do |row|
        execute("DROP INDEX IF EXISTS #{row["indexname"]}")
      end
    end
  end

  def down
    # No rollback needed - indexes were redundant
  end
end
