# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_passkey_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientPasskeyStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  DISABLED = 2
  REVOKED = 3
  DELETED = 4
  NOTHING = 5
  DEFAULTS = [ACTIVE, DISABLED, REVOKED, DELETED, NOTHING].freeze

  has_many :client_passkeys,
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_error
end
