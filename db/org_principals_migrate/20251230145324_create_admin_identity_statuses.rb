# frozen_string_literal: true

class CreateAdminIdentityStatuses < ActiveRecord::Migration[8.2]
  def up
    create_table(:admin_identity_statuses, id: :string, limit: 255) do |t|
      t.timestamps
    end

    safety_assured do
      execute("ALTER TABLE admin_identity_statuses ALTER COLUMN id SET DEFAULT 'NEYO'")
    end
  end

  def down
    drop_table(:admin_identity_statuses)
  end
end
