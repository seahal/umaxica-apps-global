# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_social_apple_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserSocialAppleStatus < PrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  has_many :user_social_apples, inverse_of: :user_social_apple_status, dependent: :restrict_with_error
end
