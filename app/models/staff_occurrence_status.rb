# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#

class StaffOccurrenceStatus < OccurrenceRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4

  include OccurrenceStatus

  has_many :staff_occurrences, foreign_key: :status_id, dependent: :restrict_with_error,
                               inverse_of: :staff_occurrence_status
end
