# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_regional_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ScavengerRegionalChronicleEvent < ChronicleRecord
  self.record_timestamps = false

  NOTHING = 0
  CREATED = 1
  STARTED = 2
  FINISHED = 3
  FAILED = 4

  has_many :scavenger_regional_chronicles,
           class_name: "ScavengerRegionalChronicle",
           foreign_key: "event_id",
           primary_key: "id",
           inverse_of: :scavenger_regional_chronicle_event,
           dependent: :restrict_with_error
end
