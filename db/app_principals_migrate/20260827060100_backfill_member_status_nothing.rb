# frozen_string_literal: true

# Moves members off the legacy MemberStatus::NOTHING id (5) onto the new id (0).
# `members.status_id` is indexed, so the scan is bounded to the legacy rows.
class BackfillMemberStatusNothing < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute("UPDATE members SET status_id = 0, updated_at = NOW() WHERE status_id = 5")
    end
  end

  def down
    safety_assured do
      execute("UPDATE members SET status_id = 5, updated_at = NOW() WHERE status_id = 0")
    end
  end
end
