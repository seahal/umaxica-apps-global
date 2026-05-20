# frozen_string_literal: true

class AddStaffSecretKindIdToStaffSecrets < ActiveRecord::Migration[8.2]
  def change
    # Step 1: Add nullable column first (for existing data)
    add_column(:staff_secrets, :staff_secret_kind_id, :string, limit: 255, null: true)

    # Step 2: Fill default for existing rows
    reversible do |dir|
      dir.up do
        safety_assured do
          execute(<<~SQL.squish)
            UPDATE staff_secrets
            SET staff_secret_kind_id = 'LOGIN'
            WHERE staff_secret_kind_id IS NULL
          SQL
        end
      end
    end

    # Step 3: Make not null
    safety_assured do
      change_column_null(:staff_secrets, :staff_secret_kind_id, false)
    end

    # Step 4: Add index
    safety_assured do
      add_index(:staff_secrets, :staff_secret_kind_id)
    end

    # Step 5: Add foreign key
    safety_assured do
      add_foreign_key(
        :staff_secrets, :staff_secret_kinds,
        column: :staff_secret_kind_id, primary_key: :id,
      )
    end
  end
end
