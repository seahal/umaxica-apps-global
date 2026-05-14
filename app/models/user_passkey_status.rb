# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_passkey_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserPasskeyStatus < PrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  DISABLED = 2
  REVOKED = 3
  DELETED = 4
  NOTHING = 5
  DEFAULTS = [ACTIVE, DISABLED, REVOKED, DELETED, NOTHING].freeze

  has_many :user_passkeys,
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_error
end
