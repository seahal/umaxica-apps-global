# typed: false
# frozen_string_literal: true

class PostTagMaster < AppPostTagMaster
  belongs_to :parent,
             class_name: "PostTagMaster",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "PostTagMaster",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :post_tags, class_name: "PostTag", dependent: :restrict_with_error, inverse_of: :post_tag_master
  has_many :posts, through: :post_tags
end

