# frozen_string_literal: true

class CreateUserMemberships < ActiveRecord::Migration[8.2]
  def up
    create_table(:user_memberships) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.references(:workspace, null: false, type: :bigint) # FK to organizations omitted (cross-db)

      t.datetime(:joined_at, null: false, default: -> { "CURRENT_TIMESTAMP" })
      t.datetime(:left_at)

      t.timestamps
    end

    add_index(:user_memberships, %i(user_id workspace_id), unique: true)
  end

  def down
    drop_table(:user_memberships)
  end
end
