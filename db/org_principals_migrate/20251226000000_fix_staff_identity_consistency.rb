# frozen_string_literal: true

class FixStaffIdentityConsistency < ActiveRecord::Migration[7.1]
  def up
    # Add level_id to staff_identity_audits if missing
    execute("ALTER TABLE staff_identity_audits ADD COLUMN IF NOT EXISTS level_id varchar(255) DEFAULT 'NONE'")

    execute(<<~SQL.squish)
      UPDATE staff_identity_audits
      SET level_id = 'NONE'
      WHERE level_id IS NULL
    SQL

    execute("ALTER TABLE staff_identity_audits ALTER COLUMN level_id SET NOT NULL")

    execute("CREATE INDEX IF NOT EXISTS index_staff_identity_audits_on_level_id ON staff_identity_audits (level_id)")
  end

  def down
    # Irreversible or manual cleanup
  end
end
