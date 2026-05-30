# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_mfa_levels
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorMfaLevel < OrgPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  WEAK = 1
  MEDIUM = 5
  FULL = 9

  DEFAULTS = [NOTHING, WEAK, MEDIUM, FULL].freeze

  has_many :staffs,
           class_name: "Operator",
           foreign_key: :mfa_level_id,
           dependent: :restrict_with_error,
           inverse_of: :mfa_level
end
