# frozen_string_literal: true

class CreateUserIdentityTelephoneStatuses < ActiveRecord::Migration[8.2]
  def up
    create_table(:user_identity_telephone_statuses, id: :string, limit: 255)

    execute("ALTER TABLE user_identity_telephone_statuses ALTER COLUMN id SET DEFAULT 'UNVERIFIED'")
  end

  def down
    drop_table(:user_identity_telephone_statuses)
  end
end
