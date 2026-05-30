# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_post_reviews
# Database name: com_publisher
#
#  id                        :bigint           not null, primary key
#  comment                   :text
#  decided_at                :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  com_post_id               :bigint           not null
#  com_post_review_status_id :bigint           not null
#  reviewer_actor_id         :bigint           not null
#
# Indexes
#
#  index_com_post_reviews_on_com_post_id_and_reviewer_actor_id  (com_post_id,reviewer_actor_id) UNIQUE
#  index_com_post_reviews_on_com_post_review_status_id          (com_post_review_status_id)
#  index_com_post_reviews_on_reviewer_actor_id                  (reviewer_actor_id) WHERE (decided_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (com_post_id => com_posts.id)
#  fk_rails_...  (com_post_review_status_id => com_post_review_statuses.id)
#
class ComPostReview < ComPublisherRecord
  belongs_to :com_post, class_name: "ComPost", inverse_of: :com_post_reviews
  belongs_to :com_post_review_status, class_name: "ComPostReviewStatus", inverse_of: :com_post_reviews

  validates :com_post_id, uniqueness: { scope: :reviewer_actor_id }
  validates :reviewer_actor_id, presence: true
end
