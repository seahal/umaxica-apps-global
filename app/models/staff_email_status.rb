# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_email_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#

class StaffEmailStatus < OperatorRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  DELETED = 2
  INACTIVE = 3
  NOTHING = 4
  PENDING = 5
  UNVERIFIED = 6
  VERIFIED = 7

  has_many :staff_emails, inverse_of: :staff_email_status, dependent: :restrict_with_error
end
