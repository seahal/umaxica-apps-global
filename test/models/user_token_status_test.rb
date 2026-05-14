# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_statuses
# Database name: mark
#
#  id :bigint           not null, primary key
#

require "test_helper"

class UserTokenStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = UserTokenStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, UserTokenStatus::ACTIVE
    assert_equal 0, UserTokenStatus::NOTHING
    assert_equal 102, UserTokenStatus::EXPIRED
    assert_equal 103, UserTokenStatus::RESTRICTED
    assert_equal 104, UserTokenStatus::REVOKED
  end
end
