# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class AppPreferenceChronicleEvent < ChronicleRecord
  self.record_timestamps = false
  # Fixed IDs - unified across App/Org/Com (aligned to Org/Com ordering)
  CREATE_NEW_PREFERENCE_TOKEN = 1
  REFRESH_TOKEN_ROTATED = 2
  UPDATE_PREFERENCE_COOKIE = 3
  UPDATE_PREFERENCE_LANGUAGE = 4
  UPDATE_PREFERENCE_TIMEZONE = 5
  RESET_BY_USER_DECISION = 6
  UPDATE_PREFERENCE_REGION = 7
  UPDATE_PREFERENCE_COLORTHEME = 8

  # Placeholder for audit event types; ids are string tokens (e.g., 'CREATED')
  has_many :app_preference_chronicles,
           class_name: "AppPreferenceChronicle",
           foreign_key: "event_id",
           primary_key: "id",
           inverse_of: :app_preference_chronicle_event,
           dependent: :restrict_with_error

  DEFAULTS = [
    CREATE_NEW_PREFERENCE_TOKEN,
    REFRESH_TOKEN_ROTATED,
    UPDATE_PREFERENCE_COOKIE,
    UPDATE_PREFERENCE_LANGUAGE,
    UPDATE_PREFERENCE_TIMEZONE,
    RESET_BY_USER_DECISION,
    UPDATE_PREFERENCE_REGION,
    UPDATE_PREFERENCE_COLORTHEME,
  ].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
