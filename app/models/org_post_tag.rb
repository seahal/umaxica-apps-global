# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_tags
# Database name: org_publisher
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  org_post_id            :bigint           not null
#  org_post_tag_master_id :bigint           default(0), not null
#
# Indexes
#
#  index_org_post_tags_on_org_post_id                             (org_post_id)
#  index_org_post_tags_on_org_post_tag_master_id_and_org_post_id  (org_post_tag_master_id,org_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (org_post_id => org_posts.id) ON DELETE => cascade
#  fk_rails_...  (org_post_tag_master_id => org_post_tag_masters.id)
#
class OrgPostTag < OrgPublisherRecord
  belongs_to :org_post, class_name: "OrgPost", inverse_of: :org_post_tags
  belongs_to :org_post_tag_master, class_name: "OrgPostTagMaster", inverse_of: :org_post_tags

  validates :org_post_tag_master_id, uniqueness: { scope: :org_post_id, message: :already_tagged }
end
