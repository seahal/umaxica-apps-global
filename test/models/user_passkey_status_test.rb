# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_passkey_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserPasskeyStatusTest < ActiveSupport::TestCase
  fixtures :user_passkey_statuses

  test "status constants are defined" do
    assert_equal 1, UserPasskeyStatus::ACTIVE
    assert_equal 2, UserPasskeyStatus::DISABLED
    assert_equal 3, UserPasskeyStatus::REVOKED
    assert_equal 4, UserPasskeyStatus::DELETED
    assert_equal 5, UserPasskeyStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, UserPasskeyStatus::ACTIVE
    assert_kind_of Integer, UserPasskeyStatus::DISABLED
    assert_kind_of Integer, UserPasskeyStatus::REVOKED
    assert_kind_of Integer, UserPasskeyStatus::DELETED
    assert_kind_of Integer, UserPasskeyStatus::NOTHING
  end

  test "default ids include every fixed status" do
    assert_equal [
      UserPasskeyStatus::ACTIVE,
      UserPasskeyStatus::DISABLED,
      UserPasskeyStatus::REVOKED,
      UserPasskeyStatus::DELETED,
      UserPasskeyStatus::NOTHING,
    ], UserPasskeyStatus::DEFAULTS
  end

  test "ensure_defaults! keeps fixed status rows present" do
    UserPasskeyStatus.ensure_defaults!

    assert_empty UserPasskeyStatus::DEFAULTS - UserPasskeyStatus.where(id: UserPasskeyStatus::DEFAULTS).pluck(:id)
  end
end
