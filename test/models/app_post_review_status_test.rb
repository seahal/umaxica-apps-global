# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_review_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#

require "test_helper"

class AppPostReviewStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = AppPostReviewStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, AppPostReviewStatus::NOTHING
    assert_equal 2, AppPostReviewStatus::ACTIVE
    assert_equal 3, AppPostReviewStatus::INACTIVE
    assert_equal 4, AppPostReviewStatus::DELETED
  end
end
