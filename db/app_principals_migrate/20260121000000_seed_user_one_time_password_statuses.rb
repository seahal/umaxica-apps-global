# frozen_string_literal: true

class SeedUserOneTimePasswordStatuses < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      %w(NEYO ACTIVE INACTIVE REVOKED DELETED).each do |status_id|
        execute(<<~SQL.squish)
          INSERT INTO user_one_time_password_statuses (id)
          VALUES ('#{status_id}')
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM user_one_time_password_statuses
        WHERE id IN ('NEYO', 'ACTIVE', 'INACTIVE', 'REVOKED', 'DELETED')
      SQL
    end
  end
end
