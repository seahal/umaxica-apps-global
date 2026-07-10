# frozen_string_literal: true

class ReconcileUserSignupReferenceRows < ActiveRecord::Migration[8.2]
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

  USER_MULTI_FACTORS = [0, 1, 5, 9].freeze

  def up
    safety_assured do
      seed_reference_rows(:user_statuses, USER_STATUSES)
      seed_reference_rows(:user_multi_factors, USER_MULTI_FACTORS.index_with { nil })
    end

    change_column_default(:users, :status_id, from: 0, to: 11) if users_status_default?(0)
    change_column_default(:users, :multi_factor_id, from: nil, to: 0) if users_multi_factor_default?(nil)
  end

  def down
    # No-op: these fixed reference rows and defaults may already be referenced by users.
  end

  private

  def seed_reference_rows(table_name, mapping)
    return unless table_exists?(table_name)

    has_code = column_exists?(table_name, :code)

    mapping.each do |id, code|
      if has_code && code.present?
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
    users_column_default?(:status_id, expected)
  end

  def users_multi_factor_default?(expected)
    users_column_default?(:multi_factor_id, expected)
  end

  def users_column_default?(column_name, expected)
    return false unless table_exists?(:users) && column_exists?(:users, column_name)

    column = columns(:users).find { |candidate| candidate.name == column_name.to_s }
    column&.default == expected&.to_s
  end
end
