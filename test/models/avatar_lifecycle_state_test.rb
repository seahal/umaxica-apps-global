# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarLifecycleStateTest < ActiveSupport::TestCase
  test "seed states exist" do
    assert_equal %w(active suspended archived banned deleted), AvatarLifecycleState.order(:sort_order).pluck(:key)
  end

  test "key is unique" do
    duplicate = AvatarLifecycleState.new(
      key: "active",
      title: "Duplicate",
      can_create_content: true,
      visible_by_default: true,
      editable_by_owner: true,
      restorable_by_owner: false,
      followable: true,
      group_attachable: true,
      discoverable: true,
      moderation_visible: true,
      terminal: false,
      sort_order: 99,
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :key
  end

  test "restricted states cannot create content or be discovered" do
    AvatarLifecycleState.where(key: %w(suspended archived banned deleted)).find_each do |state|
      assert_not state.can_create_content, "#{state.key} must not create content"
      assert_not state.discoverable, "#{state.key} must not be discoverable"
    end
  end

  test "banned and deleted are not owner restorable" do
    AvatarLifecycleState.where(key: %w(banned deleted)).find_each do |state|
      assert_not state.restorable_by_owner, "#{state.key} must not be owner restorable"
    end
  end

  test "deleted is terminal" do
    assert_predicate avatar_lifecycle_states(:deleted), :terminal
  end
end
