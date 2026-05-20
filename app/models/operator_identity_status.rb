# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

class OperatorIdentityStatus < OrgPrincipalRecord
  self.table_name = "staff_statuses"
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  NOTHING = 2
  RESERVED = 3

  DEFAULTS = [ACTIVE, NOTHING, RESERVED].freeze
  has_many :staffs,
           class_name: "Operator",
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_status
end
