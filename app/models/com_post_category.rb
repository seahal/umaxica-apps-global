# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_categories
# Database name: com_publisher
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  post_category_master_id :bigint           default(0), not null
#  post_id                 :bigint           not null
#
# Indexes
#
#  index_post_categories_on_post_category_master_id  (post_category_master_id)
#  index_post_categories_on_post_id                  (post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (post_category_master_id => post_category_masters.id)
#  fk_rails_...  (post_id => posts.id) ON DELETE => cascade
#
class ComPostCategory < ComPublisherRecord
  self.table_name = "post_categories"

  belongs_to :post, class_name: "ComPost", inverse_of: :category
  belongs_to :post_category_master, class_name: "ComPostCategoryMaster", inverse_of: :post_categories

  validates :post_id, uniqueness: true
end
