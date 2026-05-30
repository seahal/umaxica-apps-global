# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_mfa_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorMfaStatus < OrgPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  UNCONFIGURED = 5
  DEFAULTS = [NOTHING, ACTIVE, UNCONFIGURED].freeze

  has_many :staffs,
           class_name: "Operator",
           foreign_key: :mfa_status_id,
           dependent: :restrict_with_error,
           inverse_of: :mfa_status
end
