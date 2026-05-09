# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_ownership_statuses
# Database name: avatar
#
#  id :bigint           not null, primary key
#
class AvatarOwnershipStatus < AvatarRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  ACTIVE = 2
  INACTIVE = 3
  DELETED = 4

  has_many :avatar_ownership_periods, dependent: :restrict_with_error
end
