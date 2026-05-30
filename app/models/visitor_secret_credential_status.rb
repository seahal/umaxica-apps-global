# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_credential_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorSecretCredentialStatus < ComPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  EXPIRED = 2
  REVOKED = 3
  USED = 4
  DELETED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, EXPIRED, REVOKED, USED, DELETED, NOTHING].freeze

  has_many :visitor_secret_credentials, inverse_of: :visitor_secret_credential_status, dependent: :restrict_with_error
end
