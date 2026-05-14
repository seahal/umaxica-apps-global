# frozen_string_literal: true

class SeedStaffPersonnelStatuses < ActiveRecord::Migration[8.2]
  IDS = [0, 1, 2, 3].freeze

  def up
    safety_assured do
      IDS.each do |id|
        execute(<<~SQL.squish)
          INSERT INTO staff_personnel_statuses (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end

      ensure_sequence!(IDS.max)
    end
  end

  def down
    # No-op: keep shared reference data in place.
  end

  private

  def ensure_sequence!(max_id)
    sequence_name = select_value("SELECT pg_get_serial_sequence('staff_personnel_statuses', 'id')")
    return if sequence_name.blank?

    execute("SELECT setval(#{connection.quote(sequence_name)}, #{Integer(max_id)}, true)")
  end
end
