# frozen_string_literal: true

class CreateUserIdentityStatuses < ActiveRecord::Migration[8.2]
  def up
    create_table(:user_identity_statuses, id: :string, limit: 255)

    execute("ALTER TABLE user_identity_statuses ALTER COLUMN id SET DEFAULT 'NONE'")
  end

  def down
    drop_table(:user_identity_statuses)
  end
end
