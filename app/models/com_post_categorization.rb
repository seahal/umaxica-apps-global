# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_post_categorizations
# Database name: com_publisher
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  com_post_category_id :bigint           default(0), not null
#  com_post_id          :bigint           not null
#
# Indexes
#
#  index_com_post_categorizations_on_com_post_category_id  (com_post_category_id)
#  index_com_post_categorizations_on_com_post_id           (com_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (com_post_category_id => com_post_categories.id)
#  fk_rails_...  (com_post_id => com_posts.id) ON DELETE => cascade
#
class ComPostCategorization < ComPublisherRecord
  belongs_to :com_post, class_name: "ComPost", inverse_of: :com_post_categorization
  belongs_to :com_post_category, class_name: "ComPostCategory", inverse_of: :com_post_categorizations

  validates :com_post_id, uniqueness: true
end
