# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_permissions
# Database name: avatar
#
#  id :bigint           not null, primary key
#

class AvatarPermission < AvatarRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  READ = 2
  WRITE = 3
  ADMIN = 4
  DEFAULTS = [NOTHING, READ, WRITE, ADMIN].freeze

  has_many :avatar_role_permissions, dependent: :restrict_with_error
  has_many :avatar_roles, through: :avatar_role_permissions
end
