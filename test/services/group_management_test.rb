# typed: false
# frozen_string_literal: true

require "test_helper"

class GroupManagementTest < ActiveSupport::TestCase
  test "creates an account scoped active group" do
    group = GroupManagement::Create.call(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Core team",
      description: "Avatar container",
    )

    assert_predicate group, :persisted?
    assert_equal "app", group.account_surface
    assert_equal "account-public-id", group.account_public_id
    assert_equal "active", group.state
  end

  test "archives group instead of deleting it" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Archive target",
      state: "active",
    )

    GroupManagement::Archive.call(group: group)

    assert_equal "archived", group.reload.state
    assert_predicate group.archived_at, :present?
  end

  test "updates the name and description of an active group" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Before",
      state: "active",
    )

    result = GroupManagement::Update.call(
      group: group,
      attributes: { name: "After", description: "Updated description", state: "archived" },
    )

    assert_same group, result
    assert_equal "After", group.reload.name
    assert_equal "Updated description", group.description
    assert_equal "active", group.state
  end

  test "does not update an archived group" do
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: "account-public-id",
      name: "Archived",
      state: "active",
    )
    group.update_columns(state: "archived", archived_at: Time.current)
    group.reload

    error =
      assert_raises(ArgumentError) do
        GroupManagement::Update.call(group: group, attributes: { name: "Changed" })
      end

    assert_equal "group is archived", error.message
    assert_equal "Archived", group.reload.name
  end
end
