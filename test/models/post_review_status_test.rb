# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_review_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#

require "test_helper"

class PostReviewStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = PostReviewStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, PostReviewStatus::NOTHING
    assert_equal 2, PostReviewStatus::ACTIVE
    assert_equal 3, PostReviewStatus::INACTIVE
    assert_equal 4, PostReviewStatus::DELETED
  end
end
