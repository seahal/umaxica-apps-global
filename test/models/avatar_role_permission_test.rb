# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_role_permissions
# Database name: avatar
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  avatar_permission_id :bigint           default(0), not null
#  avatar_role_id       :bigint           default(0), not null
#
# Indexes
#
#  index_avatar_role_permissions_on_avatar_permission_id  (avatar_permission_id)
#  uniq_avatar_role_permissions                           (avatar_role_id,avatar_permission_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (avatar_permission_id => avatar_permissions.id)
#  fk_rails_...  (avatar_role_id => avatar_roles.id)
#
require "test_helper"

class AvatarRolePermissionTest < ActiveSupport::TestCase
  fixtures :avatar_roles, :avatar_permissions

  test "belongs to role and permission" do
    assert_equal :belongs_to, AvatarRolePermission.reflect_on_association(:avatar_role).macro
    assert_equal :belongs_to, AvatarRolePermission.reflect_on_association(:avatar_permission).macro
  end

  test "validates role permission pair uniqueness" do
    validator = AvatarRolePermission.validators_on(:avatar_role_id).grep(ActiveRecord::Validations::UniquenessValidator).first

    assert_equal :avatar_permission_id, validator.options[:scope]
  end
end
