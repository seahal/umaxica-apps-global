# typed: false
# frozen_string_literal: true

class OrgPostReview < OrgPublisherRecord
  self.table_name = "post_reviews"

  belongs_to :post, class_name: "OrgPost", inverse_of: :post_reviews
  belongs_to :post_review_status, class_name: "OrgPostReviewStatus", inverse_of: :post_reviews

  validates :post_id, uniqueness: { scope: :reviewer_actor_id }
  validates :reviewer_actor_id, presence: true
end
