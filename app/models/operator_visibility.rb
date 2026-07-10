# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_visibilities
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorVisibility < OrgPrincipalRecord
  include ReferenceRecord

  NOBODY = 0
  USER = 1
  STAFF = 2
  BOTH = 3

  DEFAULTS = [NOBODY, USER, STAFF, BOTH].freeze

  has_many :staffs,
           class_name: "Operator",
           foreign_key: :visibility_id,
           dependent: :restrict_with_error,
           inverse_of: :visibility
  has_many :operators,
           class_name: "Operator",
           foreign_key: :visibility_id,
           dependent: :restrict_with_error,
           inverse_of: :visibility
end
