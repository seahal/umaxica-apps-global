# frozen_string_literal: true

class RepairUserSocialStatusReferenceData < ActiveRecord::Migration[8.2]
  SOCIAL_STATUS_TABLES = {
    user_social_apple_statuses: {
      1 => "ACTIVE",
      2 => "INACTIVE",
      3 => "PENDING",
      4 => "DELETED",
      5 => "REVOKED",
      6 => "NEYO",
    },
    user_social_google_statuses: {
      1 => "ACTIVE",
      2 => "INACTIVE",
      3 => "PENDING",
      4 => "DELETED",
      5 => "REVOKED",
      6 => "NEYO",
    },
  }.freeze

  def up
    safety_assured do
      SOCIAL_STATUS_TABLES.each do |table_name, mapping|
        seed_reference_rows(table_name, mapping)
      end
    end

    change_column_default(:user_social_apples, :status_id, from: 0, to: 1)
    change_column_default(:user_social_googles, :status_id, from: 0, to: 1)
  end

  def down
    change_column_default(:user_social_apples, :status_id, from: 1, to: 0)
    change_column_default(:user_social_googles, :status_id, from: 1, to: 0)
  end

  private

  def seed_reference_rows(table_name, mapping)
    return unless table_exists?(table_name)

    has_code = column_exists?(table_name, :code)

    mapping.each do |id, code|
      if has_code
        execute(<<~SQL.squish)
          INSERT INTO #{table_name} (id, code)
          VALUES (#{connection.quote(id)}, #{connection.quote(code)})
          ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code
        SQL
      else
        execute(<<~SQL.squish)
          INSERT INTO #{table_name} (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end

    ensure_sequence!(table_name, mapping.keys.max)
  end

  def ensure_sequence!(table_name, max_id)
    sequence_name = select_value("SELECT pg_get_serial_sequence(#{connection.quote(table_name.to_s)}, 'id')")
    return if sequence_name.blank?

    execute("SELECT setval(#{connection.quote(sequence_name)}, #{Integer(max_id)}, true)")
  end
end
