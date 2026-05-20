# frozen_string_literal: true

class ReseedUserStatusReferenceRows < ActiveRecord::Migration[8.2]
  USER_STATUSES = {
    1 => "ACTIVE",
    2 => "INACTIVE",
    3 => "PENDING",
    4 => "DELETED",
    5 => "WITHDRAWN",
    6 => "PENDING_DELETION",
    7 => "PRE_WITHDRAWAL_CONDITION",
    8 => "WITHDRAWAL_COMPLETED",
    9 => "UNVERIFIED_WITH_SIGN_UP",
    10 => "VERIFIED_WITH_SIGN_UP",
    11 => "NEYO",
    12 => "GHOST",
    13 => "RESERVED",
  }.freeze

  def up
    return unless table_exists?(:user_statuses)

    safety_assured do
      seed_reference_rows(:user_statuses, USER_STATUSES)
    end

    change_column_default(:users, :status_id, from: 0, to: 11) if users_status_default?(0)
  end

  def down
    change_column_default(:users, :status_id, from: 11, to: 0) if users_status_default?(11)
  end

  private

  def seed_reference_rows(table_name, mapping)
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

  def users_status_default?(expected)
    return false unless table_exists?(:users) && column_exists?(:users, :status_id)

    column = columns(:users).find { |candidate| candidate.name == "status_id" }
    column&.default.to_i == expected
  end
end
