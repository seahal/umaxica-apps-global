# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_taggings
# Database name: org_publisher
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  org_post_id     :bigint           not null
#  org_post_tag_id :bigint           default(0), not null
#
# Indexes
#
#  index_org_post_taggings_on_org_post_id                      (org_post_id)
#  index_org_post_taggings_on_org_post_tag_id_and_org_post_id  (org_post_tag_id,org_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (org_post_id => org_posts.id) ON DELETE => cascade
#  fk_rails_...  (org_post_tag_id => org_post_tags.id)
#
class OrgPostTagging < OrgPublisherRecord
  belongs_to :org_post, class_name: "OrgPost", inverse_of: :org_post_taggings
  belongs_to :org_post_tag, class_name: "OrgPostTag", inverse_of: :org_post_taggings

  validates :org_post_tag_id, uniqueness: { scope: :org_post_id, message: :already_tagged }
end
