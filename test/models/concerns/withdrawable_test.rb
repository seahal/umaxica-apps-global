# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawableConcernTest < ActiveSupport::TestCase
  test "recovery and permanent deletion boundary at exactly 31 days" do
    user = User.find_by!(public_id: "one_id")

    # set withdrawn_at exactly 31 days ago
    user.update!(withdrawn_at: 31.days.ago)

    # At exactly the deadline: can_recover? should be false, permanently_deletable? should be true
    assert_not user.can_recover?, "User should not be able to recover at exact boundary"
    assert_predicate user, :permanently_deletable?
  end

  test "withdrawable methods available on user" do
    user = User.find_by!(public_id: "one_id")

    assert_respond_to user, :withdrawn?
    assert_respond_to user, :active?
    assert_respond_to user, :recovery_deadline
  end

  test "withdrawable methods available on staff" do
    staff = Operator.create!

    assert_respond_to staff, :withdrawn?
    assert_respond_to staff, :active?
    assert_respond_to staff, :recovery_deadline
  end

  # withdrawn? tests
  test "withdrawn? returns true when withdrawn_at is set" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: Time.current)

    assert_predicate user, :withdrawn?
  end

  test "withdrawn? returns false when withdrawn_at is nil" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_not user.withdrawn?
  end

  # active? tests
  test "active? returns true when withdrawn_at is nil" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_predicate user, :active?
  end

  test "active? returns false when withdrawn_at is set" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: Time.current)

    assert_not user.active?
  end

  test "active? returns false when deactivated_at is set" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil, deactivated_at: Time.current)

    assert_not user.active?
  end

  # recovery_deadline tests
  test "recovery_deadline returns nil when not withdrawn" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_nil user.recovery_deadline
  end

  test "recovery_deadline returns 31 days after withdrawn_at" do
    user = User.find_by!(public_id: "one_id")
    withdrawal_time = 1.day.ago
    user.update!(withdrawn_at: withdrawal_time)

    expected_deadline = withdrawal_time + 31.days

    assert_in_delta expected_deadline.to_i, user.recovery_deadline.to_i, 1
  end

  # can_recover? tests
  test "can_recover? returns true when withdrawn within 31 days" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 15.days.ago)

    assert_predicate user, :can_recover?
  end

  test "can_recover? returns false when not withdrawn" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_not user.can_recover?
  end

  test "can_recover? returns false when exactly 31 days have passed" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 31.days.ago)

    assert_not user.can_recover?
  end

  test "can_recover? returns false when more than 31 days have passed" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 32.days.ago)

    assert_not user.can_recover?
  end

  test "can_recover? returns true when 1 second before deadline" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 31.days.ago.advance(seconds: 1))

    assert_predicate user, :can_recover?
  end

  # permanently_deletable? tests
  test "permanently_deletable? returns false when not withdrawn" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_not user.permanently_deletable?
  end

  test "permanently_deletable? returns false when withdrawn less than 31 days ago" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 15.days.ago)

    assert_not user.permanently_deletable?
  end

  test "permanently_deletable? returns true when exactly 31 days have passed" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 31.days.ago)

    assert_predicate user, :permanently_deletable?
  end

  test "permanently_deletable? returns true when more than 31 days have passed" do
    user = User.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 32.days.ago)

    assert_predicate user, :permanently_deletable?
  end

  # withdrawn scope test
  test "withdrawn scope returns only withdrawn users" do
    user1 = User.find_by!(public_id: "one_id")
    user1.update!(withdrawn_at: 1.day.ago)

    user2 = User.find_by!(public_id: "two_id")
    user2.update!(withdrawn_at: nil)

    withdrawn_users = User.withdrawn

    assert_includes withdrawn_users, user1
    assert_not_includes withdrawn_users, user2
  end

  test "withdrawn scope returns empty when no users are withdrawn" do
    User.update_all(withdrawn_at: nil)

    withdrawn_users = User.withdrawn

    assert_empty withdrawn_users
  end

  # Staff integration tests
  test "staff withdrawn? works correctly" do
    staff = Operator.create!
    staff.update!(withdrawn_at: Time.current)

    assert_predicate staff, :withdrawn?

    staff.update!(withdrawn_at: nil)

    assert_not staff.withdrawn?
  end

  test "staff active? works correctly" do
    staff = Operator.create!
    staff.update!(withdrawn_at: nil)

    assert_predicate staff, :active?

    staff.update!(withdrawn_at: Time.current)

    assert_not staff.active?
  end

  test "staff can_recover? works correctly" do
    staff = Operator.create!
    staff.update!(withdrawn_at: 15.days.ago)

    assert_predicate staff, :can_recover?

    staff.update!(withdrawn_at: 31.days.ago)

    assert_not staff.can_recover?
  end

  test "staff permanently_deletable? works correctly" do
    staff = Operator.create!
    staff.update!(withdrawn_at: 15.days.ago)

    assert_not staff.permanently_deletable?

    staff.update!(withdrawn_at: 31.days.ago)

    assert_predicate staff, :permanently_deletable?
  end
end
