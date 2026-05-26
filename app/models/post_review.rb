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

class PostReview < AppPostReview
  belongs_to :post, class_name: "Post", inverse_of: :post_reviews
  belongs_to :post_review_status, class_name: "PostReviewStatus", inverse_of: :post_reviews
end
