# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_apple_identity_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientAppleIdentityStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, INACTIVE, PENDING, DELETED, REVOKED, NOTHING].freeze
  has_many :client_apple_identities, inverse_of: :user_apple_identity_status, dependent: :restrict_with_error
end
