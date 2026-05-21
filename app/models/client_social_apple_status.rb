# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_social_apple_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientSocialAppleStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  PENDING = 3
  DELETED = 4
  REVOKED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, INACTIVE, PENDING, DELETED, REVOKED, NOTHING].freeze
  has_many :client_social_apples, inverse_of: :user_social_apple_status, dependent: :restrict_with_error
end
