# frozen_string_literal: true

class ReconcileUserEmailStatusReferenceRows < ActiveRecord::Migration[8.2]
  USER_EMAIL_STATUSES = {
    1 => "UNVERIFIED",
    2 => "VERIFIED",
    3 => "SUSPENDED",
    4 => "DELETED",
    5 => "NEYO",
    6 => "UNVERIFIED_WITH_SIGN_UP",
    7 => "VERIFIED_WITH_SIGN_UP",
  }.freeze

  def up
    return unless table_exists?(:user_email_statuses)

    safety_assured do
      seed_reference_rows(:user_email_statuses, USER_EMAIL_STATUSES)
    end
  end

  def down
    # No-op: these fixed reference rows may already be referenced by user_emails.
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
end
