# typed: false
# frozen_string_literal: true

class PostTag < AppPostTag
  belongs_to :post, class_name: "Post", inverse_of: :post_tags
  belongs_to :post_tag_master, class_name: "PostTagMaster", inverse_of: :post_tags
end

