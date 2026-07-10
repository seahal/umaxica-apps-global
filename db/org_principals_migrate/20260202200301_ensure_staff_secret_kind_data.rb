# frozen_string_literal: true

class EnsureStaffSecretKindData < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      if table_exists?(:staff_secret_kinds)
        # Ensure default secret kinds exist
        %w(LOGIN default).each do |code|
          execute(<<~SQL.squish)
            INSERT INTO staff_secret_kinds (code)
            VALUES ('#{code}')
            ON CONFLICT (code) DO NOTHING
          SQL
        end

        # Enforce NOT NULL if not already set (should be per schema but good to be sure)
        change_column_null(:staff_secret_kinds, :code, false)
      end
    end
  end

  def down
    # Irreversible as we are adding records and setting constraints
  end
end
