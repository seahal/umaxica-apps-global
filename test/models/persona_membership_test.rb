# typed: false
# frozen_string_literal: true

require "test_helper"

class PersonaMembershipTest < ActiveSupport::TestCase
  test "revoked? is true when revoked_at is present" do
    assert_predicate PersonaMembership.new(revoked_at: Time.current), :revoked?
  end

  test "revoked? is false when revoked_at is blank" do
    assert_not PersonaMembership.new.revoked?
  end

  test "ended? is true when ends_at is present and in the past" do
    assert_predicate PersonaMembership.new(ends_at: 1.hour.ago), :ended?
  end

  test "ended? is false when ends_at is present and in the future" do
    assert_not PersonaMembership.new(ends_at: 1.hour.from_now).ended?
  end

  test "ended? is false when ends_at is blank" do
    assert_not PersonaMembership.new.ended?
  end
end
