# frozen_string_literal: true

# Aligns the column default with MemberStatus::NOTHING. Runs after the reference row exists
# and the legacy rows have been backfilled, so no insert can land on a missing foreign key.
class ChangeMembersStatusIdDefaultToNothing < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      change_column_default(:members, :status_id, from: 5, to: 0)
    end
  end

  def down
    safety_assured do
      change_column_default(:members, :status_id, from: 0, to: 5)
    end
  end
end
