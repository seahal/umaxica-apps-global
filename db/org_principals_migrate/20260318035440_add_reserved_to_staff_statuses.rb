# frozen_string_literal: true

class AddReservedToStaffStatuses < ActiveRecord::Migration[8.2]
  RESERVED_STATUS_ID = 3
  RESERVED_STATUS_CODE = "reserved"

  def up
    safety_assured do
      if column_exists?(:staff_statuses, :code)
        execute(<<~SQL.squish)
          INSERT INTO staff_statuses (id, code)
          VALUES (#{RESERVED_STATUS_ID}, '#{RESERVED_STATUS_CODE}')
          ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code
        SQL
      else
        execute(<<~SQL.squish)
          INSERT INTO staff_statuses (id)
          VALUES (#{RESERVED_STATUS_ID})
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM staff_statuses
        WHERE id = #{RESERVED_STATUS_ID}
      SQL
    end
  end
end
