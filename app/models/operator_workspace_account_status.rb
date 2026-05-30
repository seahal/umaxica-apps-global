# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_workspace_account_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorWorkspaceAccountStatus < OrgPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  NOTHING = 2
  DEFAULTS = [ACTIVE, NOTHING].freeze
  has_many :operator_workspace_accounts,
           class_name: "OperatorWorkspaceAccount",
           foreign_key: :status_id,
           inverse_of: false,
           dependent: :restrict_with_error
end
