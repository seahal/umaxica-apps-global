# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_roles
# Database name: avatar
#
#  id :bigint           not null, primary key
#

class AvatarRole < AvatarRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  VIEWER = 2
  EDITOR = 3
  ADMIN = 4
  DEFAULTS = [NOTHING, VIEWER, EDITOR, ADMIN].freeze

  has_many :avatar_role_permissions, dependent: :restrict_with_error
  has_many :avatar_permissions, through: :avatar_role_permissions
  has_many :avatar_memberships, foreign_key: :role_id, dependent: :restrict_with_error, inverse_of: :avatar_role
end
