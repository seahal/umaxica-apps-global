# frozen_string_literal: true

class SeedUserSocialGoogleStatuses < ActiveRecord::Migration[8.2]
  STATUS_IDS = %w(
    NEYO
    ACTIVE
    INACTIVE
    PENDING
    DELETED
    REVOKED
  ).freeze

  def up
    safety_assured do
      STATUS_IDS.each do |status_id|
        execute(<<~SQL.squish)
          INSERT INTO user_social_google_statuses (id)
          VALUES ('#{status_id}')
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    # No-op: keep seeded reference data in place.
  end
end
