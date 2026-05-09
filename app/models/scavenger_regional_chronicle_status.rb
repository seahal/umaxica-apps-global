# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_regional_chronicle_statuses
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ScavengerRegionalChronicleStatus < ChronicleRecord
  include ReferenceRecord

  NOTHING = 0
  STARTED = 1
  OK = 2
  ERROR = 3

  has_many :scavenger_regional_chronicles,
           class_name: "ScavengerRegionalChronicle",
           foreign_key: "status_id",
           primary_key: "id",
           inverse_of: :scavenger_regional_chronicle_status,
           dependent: :restrict_with_error
end
