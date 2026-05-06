# typed: false
# frozen_string_literal: true

namespace :data do
  desc "Normalize legacy sentinel values (NEYO/NONE) into NOTHING across all writable databases"
  task normalize_sentinel_values: :environment do
    record_bases = [
      ApplicationRecord,
      AvatarRecord,
      ChronicleRecord,
      GuestRecord,
      NotificationRecord,
      OccurrenceRecord,
      OperatorRecord,
      PrincipalRecord,
      TokenRecord,
    ]

    record_bases.each do |base|
      base.connected_to(role: :writing) do
        conn = base.connection
        db_name = conn.pool.db_config.name
        puts "[normalize_sentinel_values] scanning #{db_name}"

        conn.tables.sort.each do |table|
          columns = conn.columns(table)
          columns_by_name = columns.index_by(&:name)
          id_column = columns_by_name["id"]

          if id_column && %i(string text).include?(id_column.type)
            normalize_string_id_table(conn, table)
          end

          code_column = columns_by_name["code"]
          next unless code_column

          normalize_code_column(conn, table, id_column)
        end
      end
    end
  end

  define_method(:normalize_string_id_table) do |conn, table|
    %w(NEYO NONE).each do |legacy_id|
      next unless id_exists?(conn, table, legacy_id)

      rewire_fk_string_ids(conn, table, legacy_id, "NOTHING")
      if id_exists?(conn, table, "NOTHING")
        conn.execute("DELETE FROM #{conn.quote_table_name(table)} WHERE id = #{conn.quote(legacy_id)}")
        puts "  #{table}: deleted id=#{legacy_id} (merged to NOTHING)"
      else
        conn.execute(<<~SQL.squish)
          UPDATE #{conn.quote_table_name(table)}
          SET id = 'NOTHING'
          WHERE id = #{conn.quote(legacy_id)}
        SQL
        puts "  #{table}: renamed id=#{legacy_id} -> NOTHING"
      end
    end
  end

  define_method(:normalize_code_column) do |conn, table, id_column|
    quoted_table = conn.quote_table_name(table)
    conn.execute(<<~SQL.squish)
      UPDATE #{quoted_table}
      SET code = 'NOTHING'
      WHERE LOWER(code::text) IN ('neyo', 'none')
    SQL

    if id_column && %i(integer bigint).include?(id_column.type)
      conn.execute(<<~SQL.squish)
        UPDATE #{quoted_table}
        SET code = 'NOTHING'
        WHERE id = 0 AND (code IS NULL OR code = '' OR LOWER(code::text) IN ('neyo', 'none'))
      SQL
    end

    # `updated` is adapter-specific; log via a cheap existence probe.
    if conn.select_value("SELECT 1 FROM #{quoted_table} WHERE LOWER(code::text) IN ('neyo', 'none') LIMIT 1").nil?
      return
    end

    puts "  #{table}: has remaining non-normalized code values (manual review needed)"
  end

  define_method(:rewire_fk_string_ids) do |conn, parent_table, from_id, to_id|
    conn.tables.each do |child_table|
      conn.foreign_keys(child_table).each do |fk|
        next unless fk.to_table == parent_table
        next unless fk.primary_key.to_s == "id"

        child_column = fk.options[:column].to_s
        child_column_def = conn.columns(child_table).find { |c| c.name == child_column }
        next unless child_column_def
        next unless %i(string text).include?(child_column_def.type)

        conn.execute(<<~SQL.squish)
          UPDATE #{conn.quote_table_name(child_table)}
          SET #{conn.quote_column_name(child_column)} = #{conn.quote(to_id)}
          WHERE #{conn.quote_column_name(child_column)} = #{conn.quote(from_id)}
        SQL
      end
    end
  end

  define_method(:id_exists?) do |conn, table, value|
    conn.select_value(
      "SELECT 1 FROM #{conn.quote_table_name(table)} WHERE id = #{conn.quote(value)} LIMIT 1",
    ).present?
  end
end
