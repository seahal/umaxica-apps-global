# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class UserStatusTest < ActiveSupport::TestCase
  fixtures :user_statuses

  test "status constants are defined" do
    expected_status_constants = {
      ACTIVE: 1,
      INACTIVE: 2,
      PENDING: 3,
      DELETED: 4,
      WITHDRAWN: 5,
      PENDING_DELETION: 6,
      PRE_WITHDRAWAL_CONDITION: 7,
      WITHDRAWAL_COMPLETED: 8,
      UNVERIFIED_WITH_SIGN_UP: 9,
      VERIFIED_WITH_SIGN_UP: 10,
      NOTHING: 11,
      GHOST: 12,
      RESERVED: 13,
    }

    actual_status_constants = {
      ACTIVE: UserStatus::ACTIVE,
      INACTIVE: UserStatus::INACTIVE,
      PENDING: UserStatus::PENDING,
      DELETED: UserStatus::DELETED,
      WITHDRAWN: UserStatus::WITHDRAWN,
      PENDING_DELETION: UserStatus::PENDING_DELETION,
      PRE_WITHDRAWAL_CONDITION: UserStatus::PRE_WITHDRAWAL_CONDITION,
      WITHDRAWAL_COMPLETED: UserStatus::WITHDRAWAL_COMPLETED,
      UNVERIFIED_WITH_SIGN_UP: UserStatus::UNVERIFIED_WITH_SIGN_UP,
      VERIFIED_WITH_SIGN_UP: UserStatus::VERIFIED_WITH_SIGN_UP,
      NOTHING: UserStatus::NOTHING,
      GHOST: UserStatus::GHOST,
      RESERVED: UserStatus::RESERVED,
    }

    assert_equal expected_status_constants, actual_status_constants
  end

  test "reserved fixture exists" do
    assert_equal UserStatus::RESERVED, user_statuses(:reserved).id
  end

  test "ensure_defaults restores missing fixed status rows" do
    UserStatus.find(UserStatus::VERIFIED_WITH_SIGN_UP).destroy!

    UserStatus.ensure_defaults!

    assert UserStatus.exists?(UserStatus::VERIFIED_WITH_SIGN_UP)
    assert_empty UserStatus::DEFAULTS - UserStatus.where(id: UserStatus::DEFAULTS).pluck(:id)
  end
end
