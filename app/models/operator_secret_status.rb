# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_secret_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

class OperatorSecretStatus < OrgPrincipalRecord
  # Fixed IDs - do not modify these values
  ACTIVE = 1
  DELETED = 2
  EXPIRED = 3
  REVOKED = 4
  USED = 5

  has_many :staff_secrets, class_name: "OperatorSecret", inverse_of: :staff_secret_status,
                           dependent: :restrict_with_error
end
