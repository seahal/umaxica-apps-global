# frozen_string_literal: true

# Reference row for the new MemberStatus::NOTHING id. The old id 5 stays in place as
# MemberStatus::LEGACY_NOTHING so rows still pointing at it keep their foreign key valid
# while the backfill and default change roll out.
class SeedMemberStatusNothing < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO member_statuses (id, created_at, updated_at)
        VALUES (0, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    safety_assured do
      execute("DELETE FROM member_statuses WHERE id = 0")
    end
  end
end
