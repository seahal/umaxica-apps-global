# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorSecretStatus < ComPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  EXPIRED = 2
  REVOKED = 3
  USED = 4
  DELETED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, EXPIRED, REVOKED, USED, DELETED, NOTHING].freeze

  has_many :visitor_secrets, inverse_of: :visitor_secret_status, dependent: :restrict_with_error
end
