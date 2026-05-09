# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handle_statuses
# Database name: avatar
#
#  id :bigint           not null, primary key
#
class HandleStatus < AvatarRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  INACTIVE = 1
  PENDING = 2
  ACTIVE = 3
  DELETED = 4
  NOTHING = 5
  has_many :handles, dependent: :restrict_with_error
end
