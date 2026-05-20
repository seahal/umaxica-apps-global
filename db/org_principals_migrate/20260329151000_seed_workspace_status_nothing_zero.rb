# frozen_string_literal: true

class SeedWorkspaceStatusNothingZero < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:workspace_statuses)

    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO workspace_statuses (id)
        VALUES (0)
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    # Keep shared reference data in place once introduced.
  end
end
