# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: posts
# Database name: com_publisher
#
#  id                    :bigint           not null, primary key
#  body                  :text             not null
#  expires_at            :datetime         not null
#  lock_version          :integer          default(0), not null
#  permalink             :string(200)      not null
#  position              :integer          default(0), not null
#  published_at          :datetime         not null
#  redirect_url          :string
#  response_mode         :string           default("html"), not null
#  revision_key          :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  author_avatar_id      :bigint           not null
#  created_by_actor_id   :bigint           not null
#  latest_revision_id    :bigint
#  latest_version_id     :bigint
#  post_status_id        :bigint           not null
#  public_id             :string           not null
#  published_by_actor_id :bigint
#
# Indexes
#
#  index_posts_on_author_avatar_id_and_created_at  (author_avatar_id,created_at DESC)
#  index_posts_on_latest_revision_id               (latest_revision_id) UNIQUE
#  index_posts_on_latest_version_id                (latest_version_id) UNIQUE
#  index_posts_on_permalink                        (permalink) UNIQUE
#  index_posts_on_post_status_id                   (post_status_id)
#  index_posts_on_public_id                        (public_id) UNIQUE
#  index_posts_on_published_at_and_expires_at      (published_at,expires_at)
#
# Foreign Keys
#
#  fk_rails_...  (latest_revision_id => post_revisions.id) ON DELETE => nullify
#  fk_rails_...  (latest_version_id => post_versions.id) ON DELETE => nullify
#  fk_rails_...  (post_status_id => post_statuses.id)
#
class ComPost < ComPublisherRecord
  self.table_name = "posts"

  include PublicId
  include PublisherPostDocument

  belongs_to :author_avatar, class_name: "Avatar", inverse_of: false
  belongs_to :post_status, class_name: "ComPostStatus", inverse_of: :posts
  belongs_to :latest_version_record,
             class_name: "ComPostVersion",
             foreign_key: :latest_version_id,
             inverse_of: :latest_post,
             optional: true
  belongs_to :latest_revision_record,
             class_name: "ComPostRevision",
             foreign_key: :latest_revision_id,
             inverse_of: :latest_post,
             optional: true

  has_many :post_reviews, class_name: "ComPostReview", dependent: :restrict_with_error, inverse_of: :post
  has_many :post_versions, class_name: "ComPostVersion", dependent: :delete_all, inverse_of: :post
  has_many :post_revisions, class_name: "ComPostRevision", dependent: :delete_all, inverse_of: :post
  has_many :post_tags, class_name: "ComPostTag", dependent: :delete_all, inverse_of: :post
  has_many :tag_masters, through: :post_tags, source: :post_tag_master
  has_one :category, class_name: "ComPostCategory", dependent: :delete, inverse_of: :post
  has_one :category_master, through: :category, source: :post_category_master

  validates :public_id, presence: true, uniqueness: true
  validates :body, presence: true
  validates :created_by_actor_id, presence: true
  validates :latest_version_id, :latest_revision_id, uniqueness: { allow_nil: true }

  def latest_version
    post_versions.order(created_at: :desc).first!
  end

  def latest_revision
    post_revisions.order(created_at: :desc).first!
  end
end
