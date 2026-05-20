# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_passkey_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorPasskeyStatus < ComPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  DISABLED = 2
  REVOKED = 3
  DELETED = 4
  NOTHING = 5
  DEFAULTS = [ACTIVE, DISABLED, REVOKED, DELETED, NOTHING].freeze

  has_many :visitor_passkeys,
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_error
end
