# typed: false
# frozen_string_literal: true

class OrgPostTagMaster < OrgPublisherRecord
  self.table_name = "post_tag_masters"

  NOTHING = 0
  LEGACY_NOTHING = 1
  DEFAULTS = [NOTHING, LEGACY_NOTHING].freeze

  include PublisherPostMaster

  belongs_to :parent,
             class_name: "OrgPostTagMaster",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "OrgPostTagMaster",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :post_tags, class_name: "OrgPostTag", dependent: :restrict_with_error, inverse_of: :post_tag_master
  has_many :posts, through: :post_tags
end

