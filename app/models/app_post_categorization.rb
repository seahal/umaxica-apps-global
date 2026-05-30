# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_categorizations
# Database name: app_publisher
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  app_post_category_id :bigint           default(0), not null
#  app_post_id          :bigint           not null
#
# Indexes
#
#  index_app_post_categorizations_on_app_post_category_id  (app_post_category_id)
#  index_app_post_categorizations_on_app_post_id           (app_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (app_post_category_id => app_post_categories.id)
#  fk_rails_...  (app_post_id => app_posts.id) ON DELETE => cascade
#
class AppPostCategorization < AppPublisherRecord
  belongs_to :app_post, class_name: "AppPost", inverse_of: :app_post_categorization
  belongs_to :app_post_category, class_name: "AppPostCategory", inverse_of: :app_post_categorizations

  validates :app_post_id, uniqueness: true
end
