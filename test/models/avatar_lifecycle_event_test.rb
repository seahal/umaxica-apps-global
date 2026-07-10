# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarLifecycleEventTest < ActiveSupport::TestCase
  test "requires avatar foreign key" do
    event = AvatarLifecycleEvent.new(
      from_state_key: "active",
      to_state_key: "suspended",
      changed_by_type: "moderator",
      changed_by_public_id: "moderator-1",
      reason: "policy violation",
      metadata: {},
    )

    assert_not event.valid?
    assert_includes event.errors.attribute_names, :avatar
  end

  test "requires state keys" do
    event = AvatarLifecycleEvent.new(avatar: avatars(:one), changed_by_type: "moderator", metadata: {})

    assert_not event.valid?
    assert_includes event.errors.attribute_names, :from_state_key
    assert_includes event.errors.attribute_names, :to_state_key
  end
end
