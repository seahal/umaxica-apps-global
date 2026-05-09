# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: department_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#

class DepartmentStatus < OperatorRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4

  has_many :departments,
           inverse_of: :department_status,
           dependent: :restrict_with_error
end
