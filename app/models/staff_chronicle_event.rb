# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

class StaffChronicleEvent < ChronicleRecord
  # Fixed IDs - do not modify these values
  LOGIN_SUCCESS = 1
  AUTHORIZATION_FAILED = 2
  LOGGED_IN = 3
  LOGGED_OUT = 4
  LOGIN_FAILED = 5
  TOKEN_REFRESHED = 6
  NOTHING = 7
  STAFF_SECRET_CREATED = 8
  STAFF_SECRET_REMOVED = 9
  STAFF_SECRET_UPDATED = 10
  STEP_UP_VERIFIED = 11

  # Association with staff_chronicles
  has_many :staff_chronicles,
           foreign_key: :event_id,
           dependent: :destroy,
           inverse_of: :staff_chronicle_event

  DEFAULTS = [
    LOGIN_SUCCESS, AUTHORIZATION_FAILED, LOGGED_IN, LOGGED_OUT, LOGIN_FAILED,
    TOKEN_REFRESHED, NOTHING, STAFF_SECRET_CREATED, STAFF_SECRET_REMOVED,
    STAFF_SECRET_UPDATED, STEP_UP_VERIFIED,
  ].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
