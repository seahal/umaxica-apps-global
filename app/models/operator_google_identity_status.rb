# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_google_identity_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorGoogleIdentityStatus < OrgPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, INACTIVE, PENDING, DELETED, REVOKED, NOTHING].freeze

  has_many :operator_google_identities, inverse_of: :operator_google_identity_status,
                                        dependent: :restrict_with_error
end
