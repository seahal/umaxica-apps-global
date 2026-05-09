# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_social_google_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserSocialGoogleStatus < PrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  has_many :user_social_googles, inverse_of: :user_social_google_status, dependent: :restrict_with_error
end
