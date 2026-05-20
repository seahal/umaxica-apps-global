# frozen_string_literal: true

class AddSignUpStatusesToUserTelephoneStatuses < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      # Insert UNVERIFIED_WITH_SIGN_UP (id: 6)
      execute(<<~SQL.squish)
        INSERT INTO user_telephone_statuses (id)
        VALUES (6)
        ON CONFLICT (id) DO NOTHING
      SQL

      # Insert VERIFIED_WITH_SIGN_UP (id: 7)
      execute(<<~SQL.squish)
        INSERT INTO user_telephone_statuses (id)
        VALUES (7)
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def down
    # No-op to avoid removing shared reference data.
  end
end
