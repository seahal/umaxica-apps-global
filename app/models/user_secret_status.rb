# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_secret_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserSecretStatus < PrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  EXPIRED = 2
  REVOKED = 3
  USED = 4
  DELETED = 5
  NOTHING = 6
  has_many :user_secrets, inverse_of: :user_secret_status, dependent: :restrict_with_error
end
