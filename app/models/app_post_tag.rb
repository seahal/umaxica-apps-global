# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_tags
# Database name: app_publisher
#
#  id                     :bigint           not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  app_post_id            :bigint           not null
#  app_post_tag_master_id :bigint           default(0), not null
#
# Indexes
#
#  index_app_post_tags_on_app_post_id                             (app_post_id)
#  index_app_post_tags_on_app_post_tag_master_id_and_app_post_id  (app_post_tag_master_id,app_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (app_post_id => app_posts.id) ON DELETE => cascade
#  fk_rails_...  (app_post_tag_master_id => app_post_tag_masters.id)
#
class AppPostTag < AppPublisherRecord
  belongs_to :app_post, class_name: "AppPost", inverse_of: :app_post_tags
  belongs_to :app_post_tag_master, class_name: "AppPostTagMaster", inverse_of: :app_post_tags

  validates :app_post_tag_master_id, uniqueness: { scope: :app_post_id, message: :already_tagged }
end
