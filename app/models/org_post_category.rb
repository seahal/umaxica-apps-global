# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_categories
# Database name: org_publisher
#
#  id                          :bigint           not null, primary key
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  org_post_category_master_id :bigint           default(0), not null
#  org_post_id                 :bigint           not null
#
# Indexes
#
#  index_org_post_categories_on_org_post_category_master_id  (org_post_category_master_id)
#  index_org_post_categories_on_org_post_id                  (org_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (org_post_category_master_id => org_post_category_masters.id)
#  fk_rails_...  (org_post_id => org_posts.id) ON DELETE => cascade
#
class OrgPostCategory < OrgPublisherRecord
  belongs_to :org_post, class_name: "OrgPost", inverse_of: :org_post_category
  belongs_to :org_post_category_master, class_name: "OrgPostCategoryMaster", inverse_of: :org_post_categories

  validates :org_post_id, uniqueness: true
end
