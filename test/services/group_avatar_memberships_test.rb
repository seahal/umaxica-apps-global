# typed: false
# frozen_string_literal: true

require "test_helper"

class GroupAvatarMembershipsTest < ActiveSupport::TestCase
  test "attaches active avatar to active group" do
    capability = avatar_capabilities(:normal)
    handle = Handle.create!(handle: "group-attach-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Member")
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Group",
      state: "active",
    )

    membership = GroupAvatarMemberships::Attach.call(group: group, avatar: avatar)

    assert_predicate membership, :persisted?
    assert_equal "active", membership.state
    assert_equal avatar.id, membership.avatar_id
  end

  test "does not attach avatar to archived group" do
    capability = avatar_capabilities(:normal)
    handle = Handle.create!(handle: "group-archived-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Member")
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Group",
      state: "archived",
      archived_at: Time.current,
    )

    assert_raises(ArgumentError) do
      GroupAvatarMemberships::Attach.call(group: group, avatar: avatar)
    end
  end

  test "detach marks membership removed" do
    capability = avatar_capabilities(:normal)
    handle = Handle.create!(handle: "group-detach-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Member")
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Group",
      state: "active",
    )
    membership = GroupAvatarMembership.create!(avatar_group: group, avatar: avatar, role: "member", position: 1)

    GroupAvatarMemberships::Detach.call(membership: membership)

    assert_equal "removed", membership.reload.state
    assert_predicate membership.removed_at, :present?
  end

  test "rejects a removal timestamp before assignment" do
    assigned_at = Time.current
    membership = GroupAvatarMembership.new(
      role: "member",
      position: 0,
      state: "removed",
      assigned_at: assigned_at,
      removed_at: assigned_at - 1.second,
    )

    assert_not membership.valid?
    assert membership.errors.of_kind?(:removed_at, :invalid)
  end

  test "reorders an active membership" do
    capability = avatar_capabilities(:normal)
    handle = Handle.create!(handle: "group-reorder-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Member")
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Group",
      state: "active",
    )
    membership = GroupAvatarMembership.create!(avatar_group: group, avatar: avatar, role: "member", position: 1)

    result = GroupAvatarMemberships::Reorder.call(membership: membership, position: 3)

    assert_same membership, result
    assert_equal 3, membership.reload.position
  end

  test "does not reorder an inactive membership" do
    capability = avatar_capabilities(:normal)
    handle = Handle.create!(handle: "group-reorder-inactive-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Member")
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Group",
      state: "active",
    )
    membership = GroupAvatarMembership.create!(avatar_group: group, avatar: avatar, role: "member", position: 1)
    membership.update_columns(state: "removed", removed_at: Time.current)
    membership.reload

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Reorder.call(membership: membership, position: 3)
      end

    assert_equal "membership is not active", error.message
    assert_equal 1, membership.reload.position
  end

  test "rejects a negative reorder position" do
    capability = avatar_capabilities(:normal)
    handle = Handle.create!(handle: "group-reorder-negative-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = Avatar.create!(capability: capability, active_handle: handle, moniker: "Member")
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Group",
      state: "active",
    )
    membership = GroupAvatarMembership.create!(avatar_group: group, avatar: avatar, role: "member", position: 1)

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Reorder.call(membership: membership, position: -1)
      end

    assert_equal "position must be non-negative", error.message
    assert_equal 1, membership.reload.position
  end
end
