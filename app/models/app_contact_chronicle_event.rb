# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class AppContactChronicleEvent < ChronicleRecord
  self.record_timestamps = false

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LEGACY_NOTHING = 1
  CREATED = 2
  UPDATED = 3
  DELETED = 4
  DEFAULTS = [NOTHING, LEGACY_NOTHING, CREATED, UPDATED, DELETED].freeze

  has_many :app_contact_chronicles,
           class_name: "AppContactChronicle",
           foreign_key: "event_id",
           primary_key: "id",
           inverse_of: :app_contact_chronicle_event,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
