# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_social_google_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorSocialGoogleStatus < OrgPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, INACTIVE, PENDING, DELETED, REVOKED, NOTHING].freeze

  has_many :operator_social_googles, inverse_of: :operator_social_google_status,
                                     dependent: :restrict_with_error
end
