# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_dbsc_statuses
# Database name: mark
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserTokenDbscStatusTest < ActiveSupport::TestCase
  def setup
    UserTokenDbscStatus::DEFAULTS.each do |id|
      UserTokenDbscStatus.find_or_create_by!(id: id)
    end
  end

  test "has correct constants" do
    assert_equal 0, UserTokenDbscStatus::NOTHING
    assert_equal 1, UserTokenDbscStatus::ACTIVE
    assert_equal 2, UserTokenDbscStatus::PENDING
    assert_equal 3, UserTokenDbscStatus::FAILED
    assert_equal 4, UserTokenDbscStatus::REVOKE
  end

  test "DEFAULTS constant contains all status values" do
    expected = [0, 1, 2, 3, 4]

    assert_equal expected, UserTokenDbscStatus::DEFAULTS
  end

  test "can load nothing status from db" do
    status = UserTokenDbscStatus.find(UserTokenDbscStatus::NOTHING)

    assert_equal 0, status.id
  end

  test "has_many user_tokens association" do
    assert_respond_to UserTokenDbscStatus.new, :user_tokens
  end

  test "ensure_defaults! creates missing status records" do
    UserTokenDbscStatus.where(id: UserTokenDbscStatus::REVOKE).destroy_all

    assert_difference("UserTokenDbscStatus.count", 1) do
      UserTokenDbscStatus.ensure_defaults!
    end

    assert UserTokenDbscStatus.exists?(id: UserTokenDbscStatus::REVOKE)
  end

  test "ensure_defaults! skips existing records" do
    assert_no_difference("UserTokenDbscStatus.count") do
      UserTokenDbscStatus.ensure_defaults!
    end
  end

  test "user_tokens association works with dependent restrict" do
    status = UserTokenDbscStatus.find(UserTokenDbscStatus::NOTHING)
    user = User.create!(
      status_id: UserStatus::NOTHING,
      multi_factor_enabled: false,
    )

    user_token = UserToken.create!(
      user: user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      user_token_dbsc_status_id: status.id,
      lapses_at: 1.day.from_now,
      purge_at: 1.day.from_now,
    )

    assert_includes status.user_tokens, user_token

    assert_not status.destroy
    assert_predicate status.errors[:base], :present?
  end
end
