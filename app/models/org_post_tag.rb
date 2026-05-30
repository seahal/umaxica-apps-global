# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_post_tags
# Database name: org_publisher
#
#  id        :bigint           not null, primary key
#  parent_id :bigint           default(0), not null
#
# Indexes
#
#  index_org_post_tags_on_parent_id  (parent_id)
#
class OrgPostTag < OrgPublisherRecord
  NOTHING = 0
  LEGACY_NOTHING = 1
  DEFAULTS = [NOTHING, LEGACY_NOTHING].freeze

  include PublisherPostMaster

  belongs_to :parent,
             class_name: "OrgPostTag",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "OrgPostTag",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :org_post_taggings, class_name: "OrgPostTagging", dependent: :restrict_with_error, inverse_of: :org_post_tag
  has_many :org_posts, through: :org_post_taggings
end
