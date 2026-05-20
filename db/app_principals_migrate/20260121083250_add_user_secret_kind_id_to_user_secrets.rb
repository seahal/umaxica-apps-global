# frozen_string_literal: true

class AddUserSecretKindIdToUserSecrets < ActiveRecord::Migration[8.2]
  def change
    # Step 1: Add nullable column first (for existing data)
    add_column(:user_secrets, :user_secret_kind_id, :string, limit: 255, null: true)

    # Step 2: Fill default for existing rows
    reversible do |dir|
      dir.up do
        safety_assured do
          execute(<<~SQL.squish)
            UPDATE user_secrets
            SET user_secret_kind_id = 'LOGIN'
            WHERE user_secret_kind_id IS NULL
          SQL
        end
      end
    end

    # Step 3: Make not null
    safety_assured do
      change_column_null(:user_secrets, :user_secret_kind_id, false)
    end

    # Step 4: Add index
    safety_assured do
      add_index(:user_secrets, :user_secret_kind_id)
    end

    # Step 5: Add foreign key
    safety_assured do
      add_foreign_key(
        :user_secrets, :user_secret_kinds,
        column: :user_secret_kind_id, primary_key: :id,
      )
    end
  end
end
