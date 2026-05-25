# typed: false
# frozen_string_literal: true

class ComPostReview < ComPublisherRecord
  self.table_name = "post_reviews"

  belongs_to :post, class_name: "ComPost", inverse_of: :post_reviews
  belongs_to :post_review_status, class_name: "ComPostReviewStatus", inverse_of: :post_reviews

  validates :post_id, uniqueness: { scope: :reviewer_actor_id }
  validates :reviewer_actor_id, presence: true
end
