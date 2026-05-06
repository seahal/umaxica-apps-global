# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_contact_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ComContactChronicleEvent < ChronicleRecord
  self.record_timestamps = false

  NOTHING = 1
  CREATED = 2
  UPDATED = 3
  DELETED = 4

  has_many :com_contact_chronicles,
           class_name: "ComContactChronicle",
           foreign_key: "event_id",
           primary_key: "id",
           inverse_of: :com_contact_chronicle_event,
           dependent: :restrict_with_error
end
