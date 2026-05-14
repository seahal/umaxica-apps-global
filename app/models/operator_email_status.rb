# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_email_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#

class OperatorEmailStatus < OperatorRecord
  self.table_name = "staff_email_statuses"
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  DELETED = 2
  INACTIVE = 3
  NOTHING = 4
  PENDING = 5
  UNVERIFIED = 6
  VERIFIED = 7

  has_many :staff_emails, class_name: "OperatorEmail",
                          foreign_key: :staff_identity_email_status_id,
                          inverse_of: :staff_email_status,
                          dependent: :restrict_with_error
end
