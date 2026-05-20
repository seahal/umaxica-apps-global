# frozen_string_literal: true

class SeedStaffOneTimePasswordStatuses < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      %w(NEYO ACTIVE INACTIVE REVOKED DELETED).each do |status_id|
        execute(<<~SQL.squish)
          INSERT INTO staff_one_time_password_statuses (id, created_at, updated_at)
          VALUES ('#{status_id}', NOW(), NOW())
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM staff_one_time_password_statuses
        WHERE id IN ('NEYO', 'ACTIVE', 'INACTIVE', 'REVOKED', 'DELETED')
      SQL
    end
  end
end
