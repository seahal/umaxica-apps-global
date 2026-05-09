# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_email_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#
class CustomerEmailStatus < GuestRecord
  include ReferenceRecord

  UNVERIFIED = 1
  VERIFIED = 2
  SUSPENDED = 3
  DELETED = 4
  NOTHING = 5
  UNVERIFIED_WITH_SIGN_UP = 6
  VERIFIED_WITH_SIGN_UP = 7
  DEFAULTS = [UNVERIFIED, VERIFIED, SUSPENDED, DELETED, NOTHING, UNVERIFIED_WITH_SIGN_UP,
              VERIFIED_WITH_SIGN_UP,].freeze

  has_many :customer_emails, inverse_of: :customer_email_status, dependent: :restrict_with_error
end
