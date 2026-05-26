# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_statuses
# Database name: app_publisher
#
#  id :bigint           not null, primary key
#

require "test_helper"

class PostStatusTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    status = PostStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, PostStatus::NOTHING
    assert_equal 2, PostStatus::ACTIVE
    assert_equal 3, PostStatus::INACTIVE
    assert_equal 4, PostStatus::DELETED
  end
end
