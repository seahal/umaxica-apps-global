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
end
