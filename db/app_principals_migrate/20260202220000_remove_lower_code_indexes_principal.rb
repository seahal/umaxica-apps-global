# frozen_string_literal: true

class RemoveLowerCodeIndexesPrincipal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      indexes = connection.select_all("SELECT indexname FROM pg_indexes WHERE indexname LIKE '%_on_lower_code'").to_a
      indexes.each do |row|
        execute("DROP INDEX CONCURRENTLY IF EXISTS #{row["indexname"]}")
      end
    end
  end

  def down
  end
end
