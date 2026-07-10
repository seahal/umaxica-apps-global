# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_passkey_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

class OperatorPasskeyStatus < OrgPrincipalRecord
  # Fixed IDs - do not modify these values
  ACTIVE = 1
  REVOKED = 2

  has_many :staff_passkeys, class_name: "OperatorPasskey", foreign_key: :status_id,
                            inverse_of: :status,
                            dependent: :restrict_with_error
end
