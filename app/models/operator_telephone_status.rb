# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_telephone_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

class OperatorTelephoneStatus < OrgPrincipalRecord
  self.table_name = "staff_telephone_statuses"
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  DELETED = 2
  INACTIVE = 3
  NOTHING = 4
  PENDING = 5
  UNVERIFIED = 6
  VERIFIED = 7
  DEFAULTS = [ACTIVE, DELETED, INACTIVE, NOTHING, PENDING, UNVERIFIED, VERIFIED].freeze

  has_many :staff_telephones, class_name: "OperatorTelephone",
                              foreign_key: :staff_identity_telephone_status_id,
                              inverse_of: :staff_telephone_status,
                              dependent: :restrict_with_error
end
