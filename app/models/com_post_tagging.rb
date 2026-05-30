# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_post_taggings
# Database name: com_publisher
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  com_post_id     :bigint           not null
#  com_post_tag_id :bigint           default(0), not null
#
# Indexes
#
#  index_com_post_taggings_on_com_post_id                      (com_post_id)
#  index_com_post_taggings_on_com_post_tag_id_and_com_post_id  (com_post_tag_id,com_post_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (com_post_id => com_posts.id) ON DELETE => cascade
#  fk_rails_...  (com_post_tag_id => com_post_tags.id)
#
class ComPostTagging < ComPublisherRecord
  belongs_to :com_post, class_name: "ComPost", inverse_of: :com_post_taggings
  belongs_to :com_post_tag, class_name: "ComPostTag", inverse_of: :com_post_taggings

  validates :com_post_tag_id, uniqueness: { scope: :com_post_id, message: :already_tagged }
end
