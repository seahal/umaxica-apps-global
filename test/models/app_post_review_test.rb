# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_reviews
# Database name: app_publisher
#
#  id                        :bigint           not null, primary key
#  comment                   :text
#  decided_at                :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  app_post_id               :bigint           not null
#  app_post_review_status_id :bigint           not null
#  reviewer_actor_id         :bigint           not null
#
# Indexes
#
#  index_app_post_reviews_on_app_post_id_and_reviewer_actor_id  (app_post_id,reviewer_actor_id) UNIQUE
#  index_app_post_reviews_on_app_post_review_status_id          (app_post_review_status_id)
#  index_app_post_reviews_on_reviewer_actor_id                  (reviewer_actor_id) WHERE (decided_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (app_post_id => app_posts.id)
#  fk_rails_...  (app_post_review_status_id => app_post_review_statuses.id)
#

require "test_helper"

class AppPostReviewTest < ActiveSupport::TestCase
  fixtures :avatars, :app_post_statuses, :app_post_review_statuses, :handles, :avatar_capabilities, :handle_statuses

  test "validations" do
    review = AppPostReview.new

    assert_not review.valid?
  end

  test "validates length of id" do
    post = AppPost.create!(
      author_avatar: avatars(:one),
      app_post_status_id: AppPostStatus::NOTHING,
      public_id: "pr_test_#{SecureRandom.hex(4)}",
      body: "body",
      created_by_actor_id: "actor",
    )
    record = AppPostReview.new(
      id: 99,
      app_post: post,
      app_post_review_status_id: AppPostReviewStatus::NOTHING,
      reviewer_actor_id: "reviewer_actor",
    )

    assert_predicate record, :valid?
  end
end
