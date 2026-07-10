# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_google_identity_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientGoogleIdentityStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, INACTIVE, PENDING, DELETED, REVOKED, NOTHING].freeze
  has_many :client_google_identities, inverse_of: :user_google_identity_status, dependent: :restrict_with_error
end
