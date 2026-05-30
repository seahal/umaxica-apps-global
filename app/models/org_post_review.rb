# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_reviews
# Database name: org_publisher
#
#  id                        :bigint           not null, primary key
#  comment                   :text
#  decided_at                :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  org_post_id               :bigint           not null
#  org_post_review_status_id :bigint           not null
#  reviewer_actor_id         :bigint           not null
#
# Indexes
#
#  index_org_post_reviews_on_org_post_id_and_reviewer_actor_id  (org_post_id,reviewer_actor_id) UNIQUE
#  index_org_post_reviews_on_org_post_review_status_id          (org_post_review_status_id)
#  index_org_post_reviews_on_reviewer_actor_id                  (reviewer_actor_id) WHERE (decided_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (org_post_id => org_posts.id)
#  fk_rails_...  (org_post_review_status_id => org_post_review_statuses.id)
#
class OrgPostReview < OrgPublisherRecord
  belongs_to :org_post, class_name: "OrgPost", inverse_of: :org_post_reviews
  belongs_to :org_post_review_status, class_name: "OrgPostReviewStatus", inverse_of: :org_post_reviews

  validates :org_post_id, uniqueness: { scope: :reviewer_actor_id }
  validates :reviewer_actor_id, presence: true
end
