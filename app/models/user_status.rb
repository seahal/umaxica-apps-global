# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserStatus < PrincipalRecord
  include ReferenceRecord

  NOTHING = 11
  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  WITHDRAWN = 5
  PENDING_DELETION = 6
  PRE_WITHDRAWAL_CONDITION = 7
  WITHDRAWAL_COMPLETED = 8
  UNVERIFIED_WITH_SIGN_UP = 9
  VERIFIED_WITH_SIGN_UP = 10
  GHOST = 12
  RESERVED = 13

  DEFAULTS = [NOTHING, ACTIVE, INACTIVE, PENDING, DELETED, WITHDRAWN, PENDING_DELETION, PRE_WITHDRAWAL_CONDITION,
              WITHDRAWAL_COMPLETED, UNVERIFIED_WITH_SIGN_UP, VERIFIED_WITH_SIGN_UP, GHOST, RESERVED,].freeze

  has_many :users,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :user_status
end
