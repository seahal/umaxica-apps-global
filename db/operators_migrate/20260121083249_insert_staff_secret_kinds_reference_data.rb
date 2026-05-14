# frozen_string_literal: true

class InsertStaffSecretKindsReferenceData < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO staff_secret_kinds (id) VALUES
          ('LOGIN')
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM staff_secret_kinds WHERE id IN ('LOGIN')
      SQL
    end
  end
end
