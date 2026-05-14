# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_personnel_statuses
# Database name: personnel
#
#  id :bigint           not null, primary key
#
class OperatorPersonnelStatus < PersonnelRecord
  self.table_name = "staff_personnel_statuses"
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  SUSPENDED = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, SUSPENDED, DELETED].freeze

  has_many :staff_personnels, class_name: "OperatorPersonnel", foreign_key: :status_id,
                              dependent: :restrict_with_error,
                              inverse_of: :staff_personnel_status
end
