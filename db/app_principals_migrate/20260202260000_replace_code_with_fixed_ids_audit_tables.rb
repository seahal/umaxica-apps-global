# frozen_string_literal: true

class ReplaceCodeWithFixedIdsAuditTables < ActiveRecord::Migration[8.0]
  def up
    target_tables = {
      user_identity_audit_events: {
        1 => "NEYO",
        2 => "CREATED",
        3 => "UPDATED",
        4 => "DELETED",
      },
      user_identity_audit_levels: {
        1 => "NEYO",
        2 => "DEBUG",
        3 => "INFO",
        4 => "WARN",
        5 => "ERROR",
      },
    }

    safety_assured do
      target_tables.each do |table_name, mapping|
        # 1. Truncate table and cascade to clear references
        execute("TRUNCATE TABLE #{table_name} RESTART IDENTITY CASCADE")

        # 2. Insert fixed IDs
        mapping.each do |id, code|
          execute("INSERT INTO #{table_name} (id, code) VALUES (#{id}, '#{code}')")
        end

        # 3. Update sequence
        max_id = mapping.keys.max
        execute("SELECT setval(pg_get_serial_sequence('#{table_name}', 'id'), #{max_id})")

        # 4. Remove code column and index
        remove_column(table_name, :code)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
