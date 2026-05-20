# frozen_string_literal: true

class SeedMemberStatuses < ActiveRecord::Migration[8.2]
  def up
    return if table_exists?(:member_statuses) && member_statuses_empty?

    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO member_statuses (id, created_at, updated_at) VALUES
        (1, NOW(), NOW()),
        (2, NOW(), NOW()),
        (3, NOW(), NOW()),
        (4, NOW(), NOW()),
        (5, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    safety_assured do
      execute("DELETE FROM member_statuses")
    end
  end

  private

  def member_statuses_empty?
    !ActiveRecord::Base.connection.execute("SELECT 1 FROM member_statuses LIMIT 1").to_a.empty?
  end
end
