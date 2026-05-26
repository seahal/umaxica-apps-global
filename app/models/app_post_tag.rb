# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_tags
# Database name: app_publisher
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  post_id            :bigint           not null
#  post_tag_master_id :bigint           default(0), not null
#
# Indexes
#
#  index_post_tags_on_post_id                         (post_id)
#  index_post_tags_on_post_tag_master_id_and_post_id  (post_tag_master_id,post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id) ON DELETE => cascade
#  fk_rails_...  (post_tag_master_id => post_tag_masters.id)
#
class AppPostTag < AppPublisherRecord
  self.table_name = "post_tags"

  belongs_to :post, class_name: "AppPost", inverse_of: :post_tags
  belongs_to :post_tag_master, class_name: "AppPostTagMaster", inverse_of: :post_tags

  validates :post_tag_master_id, uniqueness: { scope: :post_id, message: :already_tagged }
end
