# frozen_string_literal: true

class SeedGuestCategories < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # No-op: data seeding moved to fixtures.
  end

  def down
    # No-op: data seeding moved to fixtures.
  end

  private

  def upsert_table(table_name, rows)
    now = Time.current
    has_created_at = connection.column_exists?(table_name, :created_at)
    has_updated_at = connection.column_exists?(table_name, :updated_at)

    rows.each do |row|
      row[:created_at] ||= now if has_created_at
      row[:updated_at] ||= now if has_updated_at

      cols = row.keys.join(", ")
      vals = row.values.map { |v| connection.quote(v) }.join(", ")

      updates = row.keys.map do |k|
        "#{k} = EXCLUDED.#{k}"
      end.join(", ")

      sql = <<~SQL.squish
        INSERT INTO #{table_name} (#{cols})
        VALUES (#{vals})
        ON CONFLICT (id) DO UPDATE SET #{updates}
      SQL

      execute(sql)
    end
  end
end
