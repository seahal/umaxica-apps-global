# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: posts
# Database name: avatar
#
#  id                    :bigint           not null, primary key
#  body                  :text             not null
#  published_at          :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  author_avatar_id      :bigint           not null
#  created_by_actor_id   :bigint           not null
#  post_status_id        :bigint           default(0), not null
#  public_id             :string           not null
#  published_by_actor_id :bigint
#
# Indexes
#
#  index_posts_on_author_avatar_id_and_created_at  (author_avatar_id,created_at DESC)
#  index_posts_on_post_status_id                   (post_status_id)
#  index_posts_on_public_id                        (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_avatar_id => avatars.id)
#  fk_rails_...  (post_status_id => post_statuses.id)
#

class Post < AppPost
  belongs_to :post_status, class_name: "PostStatus", inverse_of: :posts
  belongs_to :latest_version_record,
             class_name: "PostVersion",
             foreign_key: :latest_version_id,
             inverse_of: :latest_post,
             optional: true
  belongs_to :latest_revision_record,
             class_name: "PostRevision",
             foreign_key: :latest_revision_id,
             inverse_of: :latest_post,
             optional: true

  has_many :post_reviews, class_name: "PostReview", dependent: :restrict_with_error, inverse_of: :post
  has_many :post_versions, class_name: "PostVersion", dependent: :delete_all, inverse_of: :post
  has_many :post_revisions, class_name: "PostRevision", dependent: :delete_all, inverse_of: :post
  has_many :post_tags, class_name: "PostTag", dependent: :delete_all, inverse_of: :post
  has_many :tag_masters, through: :post_tags, source: :post_tag_master
  has_one :category, class_name: "PostCategory", dependent: :delete, inverse_of: :post
  has_one :category_master, through: :category, source: :post_category_master
end
