# typed: false
# frozen_string_literal: true

class PostCategory < AppPostCategory
  belongs_to :post, class_name: "Post", inverse_of: :category
  belongs_to :post_category_master, class_name: "PostCategoryMaster", inverse_of: :post_categories
end

