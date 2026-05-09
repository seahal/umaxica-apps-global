# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: division_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#
class DivisionStatus < OperatorRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4

  has_many :divisions, dependent: :restrict_with_error

  self.primary_key = "id"
end
