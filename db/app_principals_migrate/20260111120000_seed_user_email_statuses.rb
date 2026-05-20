# frozen_string_literal: true

class SeedUserEmailStatuses < ActiveRecord::Migration[8.2]
  STATUS_IDS = %w(
    NEYO
    UNVERIFIED_WITH_SIGN_UP
    VERIFIED_WITH_SIGN_UP
    UNVERIFIED
    VERIFIED
    SUSPENDED
    DELETED
  ).freeze

  def up
    safety_assured do
      STATUS_IDS.each do |status_id|
        execute(<<~SQL.squish)
          INSERT INTO user_email_statuses (id)
          VALUES ('#{status_id}')
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    # No-op to avoid removing shared reference data.
  end
end
