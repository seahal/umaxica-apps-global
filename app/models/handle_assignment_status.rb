# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handle_assignment_statuses
# Database name: avatar
#
#  id :bigint           not null, primary key
#
class HandleAssignmentStatus < AvatarRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  INACTIVE = 1
  PENDING = 2
  ACTIVE = 3
  DELETED = 4
  NOTHING = 5
  has_many :handle_assignments, dependent: :restrict_with_error
end
