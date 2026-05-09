# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_telephone_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserTelephoneStatus < PrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  VERIFIED = 1
  UNVERIFIED = 2
  SUSPENDED = 3
  DELETED = 4
  LEGACY_NOTHING = 5
  UNVERIFIED_WITH_SIGN_UP = 6
  VERIFIED_WITH_SIGN_UP = 7
  DEFAULTS = [NOTHING, VERIFIED, UNVERIFIED, SUSPENDED, DELETED, LEGACY_NOTHING,
              UNVERIFIED_WITH_SIGN_UP, VERIFIED_WITH_SIGN_UP,].freeze

  has_many :user_telephones, inverse_of: :user_telephone_status, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
