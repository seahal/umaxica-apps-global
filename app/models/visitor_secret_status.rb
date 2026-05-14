# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#
class VisitorSecretStatus < GuestRecord
  include ReferenceRecord

  ACTIVE = 1
  EXPIRED = 2
  REVOKED = 3
  USED = 4
  DELETED = 5
  NOTHING = 6

  has_many :visitor_secrets, inverse_of: :visitor_secret_status, dependent: :restrict_with_error
end
