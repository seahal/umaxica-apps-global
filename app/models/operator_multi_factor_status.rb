# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_multi_factor_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorMultiFactorStatus < OrgPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  UNCONFIGURED = 5
  DEFAULTS = [NOTHING, ACTIVE, UNCONFIGURED].freeze

  has_many :staffs,
           class_name: "Operator",
           foreign_key: :multi_factor_status_id,
           dependent: :restrict_with_error,
           inverse_of: :multi_factor_status
end
