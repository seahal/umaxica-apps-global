# typed: false
# frozen_string_literal: true

class ComPostCategory < ComPublisherRecord
  self.table_name = "post_categories"

  belongs_to :post, class_name: "ComPost", inverse_of: :category
  belongs_to :post_category_master, class_name: "ComPostCategoryMaster", inverse_of: :post_categories

  validates :post_id, uniqueness: true
end

