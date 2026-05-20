# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpLinkTest < ActiveSupport::TestCase
  setup do
    [AppJumpLink, ComJumpLink, OrgJumpLink].each(&:delete_all)
  end

  test "generates public_id" do
    jump_link = AppJumpLink.create!(destination_url: "https://destination.example/path")

    assert_equal 21, jump_link.public_id.length
  end

  test "fills sentinel timestamps" do
    jump_link = AppJumpLink.create!(destination_url: "https://destination.example/path")

    assert_equal Float::INFINITY, jump_link.discarded_at
    assert_equal Float::INFINITY, jump_link.purged_at
  end

  test "availability requires active status" do
    active = AppJumpLink.create!(destination_url: "https://destination.example/active")
    disabled = AppJumpLink.create!(
      destination_url: "https://destination.example/disabled",
      status_id: JumpLinkable::STATUS_DISABLED,
    )
    revoked = AppJumpLink.create!(
      destination_url: "https://destination.example/revoked",
      status_id: JumpLinkable::STATUS_REVOKED,
      discarded_at: 1.minute.ago,
    )

    assert active.available_for?(user: nil)
    assert_not disabled.available_for?(user: nil)
    assert_not revoked.available_for?(user: nil)
  end

  test "max_uses zero is unlimited" do
    jump_link = AppJumpLink.create!(
      destination_url: "https://destination.example/unlimited",
      max_uses: 0,
      uses_count: 10,
    )

    assert jump_link.available_for?(user: nil)
  end

  test "max_uses blocks after limit" do
    jump_link = AppJumpLink.create!(
      destination_url: "https://destination.example/limited",
      max_uses: 1,
      uses_count: 1,
    )

    assert_not jump_link.available_for?(user: nil)
  end

  test "consume increments uses_count and blocks after max_uses" do
    jump_link = AppJumpLink.create!(
      destination_url: "https://destination.example/consume",
      max_uses: 1,
    )

    assert_equal "https://destination.example/consume", jump_link.consume_destination_for(user: nil)
    assert_nil jump_link.consume_destination_for(user: nil)
    assert_equal 1, jump_link.reload.uses_count
  end

  test "revoke! marks link revoked" do
    jump_link = AppJumpLink.create!(destination_url: "https://destination.example/revoke")

    jump_link.revoke!

    assert_equal JumpLinkable::STATUS_REVOKED, jump_link.status_id
    assert_predicate jump_link.discarded_at, :present?
  end

  test "models have strict tld mapping" do
    assert_equal "jump.example.app", AppJumpLink::TLD_HOST
    assert_equal "jump.example.com", ComJumpLink::TLD_HOST
    assert_equal "jump.example.org", OrgJumpLink::TLD_HOST
  end
end
