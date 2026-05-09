# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_contact_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class OrgContactChronicleEvent < ChronicleRecord
  include ReferenceRecord

  NOTHING = 1
  CREATED = 2
  UPDATED = 3
  DELETED = 4

  has_many :org_contact_chronicles,
           class_name: "OrgContactChronicle",
           foreign_key: "event_id",
           primary_key: "id",
           inverse_of: :org_contact_chronicle_event,
           dependent: :restrict_with_error
end
