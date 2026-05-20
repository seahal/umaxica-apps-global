# frozen_string_literal: true

class SeedUserReferenceData < ActiveRecord::Migration[8.2]
  USER_STATUS_IDS = %w(
    NEYO
    ACTIVE
    INACTIVE
    PENDING
    DELETED
    WITHDRAWN
    PRE_WITHDRAWAL_CONDITION
    UNVERIFIED_WITH_SIGN_UP
    VERIFIED_WITH_SIGN_UP
  ).freeze

  USER_DEFINITIONS = {
    placeholder: {
      id: "0",
      public_id: "placeholder_id",
      status_id: "NEYO",
    },
  }.freeze

  USER_EMAIL_DEFINITIONS = [].freeze

  def up
    safety_assured do
      seed_user_statuses
      seed_users
      seed_user_emails
    end
  end

  def down
    # No-op: keep seeded reference data in place.
  end

  private

  def seed_user_statuses
    USER_STATUS_IDS.each do |status_id|
      execute(<<~SQL.squish)
        INSERT INTO user_statuses (id)
        VALUES ('#{status_id}')
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def seed_users
    USER_DEFINITIONS.each_value do |user|
      execute(<<~SQL.squish)
        INSERT INTO users (id, public_id, status_id, created_at, updated_at)
        VALUES (
          '#{user[:id]}',
          '#{user[:public_id]}',
          '#{user[:status_id]}',
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end

  def seed_user_emails
    USER_EMAIL_DEFINITIONS.each do |entry|
      user = USER_DEFINITIONS[entry[:user]]
      next unless user

      execute(<<~SQL.squish)
        INSERT INTO user_emails (
          id,
          address,
          created_at,
          updated_at,
          user_id,
          user_email_status_id
        )
        VALUES (
          '#{entry[:id]}',
          '#{entry[:address]}',
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP,
          '#{user[:id]}',
          '#{entry[:user_email_status_id]}'
        )
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end
end
