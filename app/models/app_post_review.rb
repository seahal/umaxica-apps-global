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
class AppPostReview < AppPublisherRecord
  belongs_to :app_post, class_name: "AppPost", inverse_of: :app_post_reviews
  belongs_to :app_post_review_status, class_name: "AppPostReviewStatus", inverse_of: :app_post_reviews

  validates :app_post_id, uniqueness: { scope: :reviewer_actor_id }
  validates :reviewer_actor_id, presence: true
end
