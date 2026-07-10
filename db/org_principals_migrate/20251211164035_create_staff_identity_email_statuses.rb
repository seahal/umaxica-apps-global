# frozen_string_literal: true

class CreateStaffIdentityEmailStatuses < ActiveRecord::Migration[8.2]
  def up
    create_table(:staff_identity_email_statuses, id: :string, limit: 255)

    execute("ALTER TABLE staff_identity_email_statuses ALTER COLUMN id SET DEFAULT 'UNVERIFIED'")
  end

  def down
    drop_table(:staff_identity_email_statuses)
  end
end
