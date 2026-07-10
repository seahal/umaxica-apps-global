# frozen_string_literal: true

class PrincipalReferenceTableTimestampsRemoval < ActiveRecord::Migration[8.2]
  TARGET_TABLES = %i(
    client_statuses
    user_identity_audit_events
    user_identity_audit_levels
  ).freeze

  def up
    TARGET_TABLES.each do |table|
      next unless table_exists?(table)

      safety_assured do
        remove_column(table, :created_at) if column_exists?(table, :created_at)
        remove_column(table, :updated_at) if column_exists?(table, :updated_at)
      end
    end
  end

  def down
    TARGET_TABLES.each do |table|
      next unless table_exists?(table)

      safety_assured do
        add_column(
          table,
          :created_at,
          :datetime,
          null: false,
          default: -> { "CURRENT_TIMESTAMP" },
        ) unless column_exists?(table, :created_at)
        add_column(
          table,
          :updated_at,
          :datetime,
          null: false,
          default: -> { "CURRENT_TIMESTAMP" },
        ) unless column_exists?(table, :updated_at)

        change_column_default(table, :created_at, nil) if column_exists?(table, :created_at)
        change_column_default(table, :updated_at, nil) if column_exists?(table, :updated_at)
      end
    end
  end
end
