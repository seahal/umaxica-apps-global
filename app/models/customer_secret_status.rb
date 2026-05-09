# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_secret_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#
class CustomerSecretStatus < GuestRecord
  include ReferenceRecord

  ACTIVE = 1
  EXPIRED = 2
  REVOKED = 3
  USED = 4
  DELETED = 5
  NOTHING = 6

  has_many :customer_secrets, inverse_of: :customer_secret_status, dependent: :restrict_with_error
end
