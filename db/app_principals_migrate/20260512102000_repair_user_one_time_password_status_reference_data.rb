# frozen_string_literal: true

class RepairUserOneTimePasswordStatusReferenceData < ActiveRecord::Migration[8.2]
  STATUS_IDS = {
    1 => "ACTIVE",
    2 => "INACTIVE",
    3 => "REVOKED",
    4 => "DELETED",
    5 => "NEYO",
  }.freeze

  def up
    return unless table_exists?(:user_one_time_password_statuses)

    safety_assured do
      STATUS_IDS.each_key do |id|
        execute(<<~SQL.squish)
          INSERT INTO user_one_time_password_statuses (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end

      ensure_sequence!
    end
  end

  def down
    # Keep shared reference data in place; removing rows can break existing TOTP foreign keys.
  end

  private

  def ensure_sequence!
    sequence_name = select_value("SELECT pg_get_serial_sequence('user_one_time_password_statuses', 'id')")
    return if sequence_name.blank?

    execute("SELECT setval(#{connection.quote(sequence_name)}, #{STATUS_IDS.keys.max}, true)")
  end
end
