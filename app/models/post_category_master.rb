# typed: false
# frozen_string_literal: true

class PostCategoryMaster < AppPostCategoryMaster
  belongs_to :parent,
             class_name: "PostCategoryMaster",
             inverse_of: :children,
             optional: true
  has_many :children,
           class_name: "PostCategoryMaster",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_error
  has_many :post_categories, class_name: "PostCategory", dependent: :restrict_with_error, inverse_of: :post_category_master
  has_many :posts, through: :post_categories
end
