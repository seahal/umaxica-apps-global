# frozen_string_literal: true

class CreateStaffIdentityStatuses < ActiveRecord::Migration[8.2]
  def up
    create_table(:staff_identity_statuses, id: :string, limit: 255)

    execute("ALTER TABLE staff_identity_statuses ALTER COLUMN id SET DEFAULT 'NONE'")
  end

  def down
    drop_table(:staff_identity_statuses)
  end
end
