# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_categorizations
# Database name: org_publisher
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  org_post_category_id :bigint           default(0), not null
#  org_post_id          :bigint           not null
#
# Indexes
#
#  index_org_post_categorizations_on_org_post_category_id  (org_post_category_id)
#  index_org_post_categorizations_on_org_post_id           (org_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (org_post_category_id => org_post_categories.id)
#  fk_rails_...  (org_post_id => org_posts.id) ON DELETE => cascade
#
class OrgPostCategorization < OrgPublisherRecord
  belongs_to :org_post, class_name: "OrgPost", inverse_of: :org_post_categorization
  belongs_to :org_post_category, class_name: "OrgPostCategory", inverse_of: :org_post_categorizations

  validates :org_post_id, uniqueness: true
end
