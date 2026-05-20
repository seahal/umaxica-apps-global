# frozen_string_literal: true

class SeedIdentityAuditEventsAndLevels < ActiveRecord::Migration[8.2]
  USER_EVENTS = %w(
    LOGIN_SUCCESS
    LOGIN_FAILURE
    LOGGED_IN
    LOGGED_OUT
    LOGIN_FAILED
    TOKEN_REFRESHED
    SIGNED_UP_WITH_EMAIL
    SIGNED_UP_WITH_TELEPHONE
    SIGNED_UP_WITH_APPLE
    AUTHORIZATION_FAILED
  ).freeze

  STAFF_EVENTS = %w(
    LOGIN_SUCCESS
    LOGIN_FAILURE
    LOGGED_IN
    LOGGED_OUT
    LOGIN_FAILED
    AUTHORIZATION_FAILED
  ).freeze

  LEVELS = %w(NONE INFO WARN ERROR).freeze

  def up
    seed_ids(:user_identity_audit_events, USER_EVENTS)
    seed_ids(:staff_identity_audit_events, STAFF_EVENTS)
    seed_ids(:user_identity_audit_levels, LEVELS)
    seed_ids(:staff_identity_audit_levels, LEVELS)
  end

  def down
    # No-op to avoid removing shared reference data.
  end

  private

  def seed_ids(table_name, ids)
    return unless table_exists?(table_name)

    # Check if table has timestamp columns
    has_timestamps = column_exists?(table_name, :created_at)

    ids.each do |_id|
      if has_timestamps
      else
      end
    end
  end
end
