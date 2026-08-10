# typed: false
# frozen_string_literal: true

require "test_helper"

class GroupAvatarMembershipPolicyTest < ActiveSupport::TestCase
  setup do
    Actor.install_context!(selection: Actor::SelectedContext.new(account_public_id: "account-1"))
  end

  teardown { Actor.clear }

  test "client can manage active membership for selected app group" do
    group = AvatarGroup.new(account_surface: "app", account_public_id: "account-1", state: "active")
    membership = GroupAvatarMembership.new(avatar_group: group, state: "active")
    policy = GroupAvatarMembershipPolicy.new(membership, user: Client.new)

    assert_predicate policy, :create?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  test "non-client and wrong account memberships are denied" do
    selected_group = AvatarGroup.new(account_surface: "app", account_public_id: "account-1", state: "active")
    wrong_group = AvatarGroup.new(account_surface: "app", account_public_id: "account-2", state: "active")
    selected_membership = GroupAvatarMembership.new(avatar_group: selected_group, state: "active")
    wrong_membership = GroupAvatarMembership.new(avatar_group: wrong_group, state: "active")

    assert_not GroupAvatarMembershipPolicy.new(selected_membership, user: Visitor.new).create?
    assert_not GroupAvatarMembershipPolicy.new(wrong_membership, user: Client.new).create?
    assert_not GroupAvatarMembershipPolicy.new(Object.new, user: Client.new).create?
  end

  test "removed membership cannot be updated or destroyed" do
    group = AvatarGroup.new(account_surface: "app", account_public_id: "account-1", state: "active")
    membership = GroupAvatarMembership.new(
      avatar_group: group, state: "removed", assigned_at: 1.day.ago, removed_at: Time.current,
    )
    policy = GroupAvatarMembershipPolicy.new(membership, user: Client.new)

    assert_not policy.update?
    assert_not policy.destroy?
  end
end
