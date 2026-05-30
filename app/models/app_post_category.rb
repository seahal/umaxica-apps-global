# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_categories
# Database name: app_publisher
#
#  id                          :bigint           not null, primary key
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  app_post_category_master_id :bigint           default(0), not null
#  app_post_id                 :bigint           not null
#
# Indexes
#
#  index_app_post_categories_on_app_post_category_master_id  (app_post_category_master_id)
#  index_app_post_categories_on_app_post_id                  (app_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (app_post_category_master_id => app_post_category_masters.id)
#  fk_rails_...  (app_post_id => app_posts.id) ON DELETE => cascade
#
class AppPostCategory < AppPublisherRecord
  belongs_to :app_post, class_name: "AppPost", inverse_of: :app_post_category
  belongs_to :app_post_category_master, class_name: "AppPostCategoryMaster", inverse_of: :app_post_categories

  validates :app_post_id, uniqueness: true
end
