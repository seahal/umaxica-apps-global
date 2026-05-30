# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AppPostStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = AppPostStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, AppPostStatus::NOTHING
    assert_equal 2, AppPostStatus::ACTIVE
    assert_equal 3, AppPostStatus::INACTIVE
    assert_equal 4, AppPostStatus::DELETED
  end
end
