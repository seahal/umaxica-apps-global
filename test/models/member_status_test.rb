# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: member_statuses
# Database name: app_principal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class MemberStatusTest < ActiveSupport::TestCase
  test "has correct constant values" do
    assert_equal 0, MemberStatus::NOTHING
    assert_equal 1, MemberStatus::ACTIVE
    assert_equal 2, MemberStatus::INACTIVE
    assert_equal 3, MemberStatus::PENDING
    assert_equal 4, MemberStatus::DELETED
    assert_equal 5, MemberStatus::LEGACY_NOTHING
  end
end
