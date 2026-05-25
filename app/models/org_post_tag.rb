# typed: false
# frozen_string_literal: true

class OrgPostTag < OrgPublisherRecord
  self.table_name = "post_tags"

  belongs_to :post, class_name: "OrgPost", inverse_of: :post_tags
  belongs_to :post_tag_master, class_name: "OrgPostTagMaster", inverse_of: :post_tags

  validates :post_tag_master_id, uniqueness: { scope: :post_id, message: :already_tagged }
end

