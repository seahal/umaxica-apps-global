# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_totp_credential_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientTotpCredentialStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  REVOKED = 3
  DELETED = 4
  NOTHING = 5
  DEFAULTS = [ACTIVE, INACTIVE, REVOKED, DELETED, NOTHING].freeze

  has_many :client_totp_credentials, dependent: :restrict_with_error,
                                     inverse_of: :user_totp_credential_status
end
