# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_reviews
# Database name: app_publisher
#
#  id                    :bigint           not null, primary key
#  comment               :text
#  decided_at            :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  post_id               :bigint           not null
#  post_review_status_id :bigint           not null
#  reviewer_actor_id     :bigint           not null
#
# Indexes
#
#  index_post_reviews_on_post_id_and_reviewer_actor_id  (post_id,reviewer_actor_id) UNIQUE
#  index_post_reviews_on_post_review_status_id          (post_review_status_id)
#  index_post_reviews_on_reviewer_actor_id              (reviewer_actor_id) WHERE (decided_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id)
#  fk_rails_...  (post_review_status_id => post_review_statuses.id)
#

require "test_helper"

class PostReviewTest < ActiveSupport::TestCase
  fixtures :avatars, :post_statuses, :post_review_statuses, :handles, :avatar_capabilities, :handle_statuses

  test "validations" do
    review = PostReview.new

    assert_not review.valid?
  end

  test "validates length of id" do
    post = Post.create!(
      author_avatar: avatars(:one),
      post_status_id: PostStatus::NOTHING,
      public_id: "pr_test_#{SecureRandom.hex(4)}",
      body: "body",
      created_by_actor_id: "actor",
    )
    record = PostReview.new(
      id: 99,
      post: post,
      post_review_status_id: PostReviewStatus::NOTHING,
      reviewer_actor_id: "reviewer_actor",
    )

    assert_predicate record, :valid?
  end
end
