# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#

class StaffStatus < OperatorRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  NOTHING = 2
  RESERVED = 3
  has_many :staffs,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_status
end
