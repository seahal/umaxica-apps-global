# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: scavenger_global_chronicle_statuses
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ScavengerGlobalChronicleStatus < ChronicleRecord
  include ReferenceRecord

  NOTHING = 0
  STARTED = 1
  OK = 2
  ERROR = 3

  has_many :scavenger_global_chronicles,
           class_name: "ScavengerGlobalChronicle",
           foreign_key: "status_id",
           primary_key: "id",
           inverse_of: :scavenger_global_chronicle_status,
           dependent: :restrict_with_error
end
