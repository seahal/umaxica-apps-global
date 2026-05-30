# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_post_categories
# Database name: com_publisher
#
#  id                          :bigint           not null, primary key
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  com_post_category_master_id :bigint           default(0), not null
#  com_post_id                 :bigint           not null
#
# Indexes
#
#  index_com_post_categories_on_com_post_category_master_id  (com_post_category_master_id)
#  index_com_post_categories_on_com_post_id                  (com_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (com_post_category_master_id => com_post_category_masters.id)
#  fk_rails_...  (com_post_id => com_posts.id) ON DELETE => cascade
#
class ComPostCategory < ComPublisherRecord
  belongs_to :com_post, class_name: "ComPost", inverse_of: :com_post_category
  belongs_to :com_post_category_master, class_name: "ComPostCategoryMaster", inverse_of: :com_post_categories

  validates :com_post_id, uniqueness: true
end
