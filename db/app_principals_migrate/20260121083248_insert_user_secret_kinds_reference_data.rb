# frozen_string_literal: true

class InsertUserSecretKindsReferenceData < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO user_secret_kinds (id) VALUES
          ('LOGIN'), ('TOTP'), ('RECOVERY'), ('API')
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        DELETE FROM user_secret_kinds WHERE id IN ('LOGIN', 'TOTP', 'RECOVERY', 'API')
      SQL
    end
  end
end
