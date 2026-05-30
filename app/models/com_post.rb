# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_posts
# Database name: com_publisher
#
#  id                          :bigint           not null, primary key
#  body                        :text             not null
#  expires_at                  :datetime         not null
#  lock_version                :integer          default(0), not null
#  permalink                   :string(200)      not null
#  position                    :integer          default(0), not null
#  published_at                :datetime         not null
#  redirect_url                :string
#  response_mode               :string           default("html"), not null
#  revision_key                :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  author_avatar_id            :bigint           not null
#  com_post_status_id          :bigint           not null
#  created_by_actor_id         :bigint           not null
#  latest_com_post_revision_id :bigint
#  latest_com_post_version_id  :bigint
#  public_id                   :string           not null
#  published_by_actor_id       :bigint
#
# Indexes
#
#  index_com_posts_on_author_avatar_id_and_created_at  (author_avatar_id,created_at DESC)
#  index_com_posts_on_com_post_status_id               (com_post_status_id)
#  index_com_posts_on_latest_com_post_revision_id      (latest_com_post_revision_id) UNIQUE
#  index_com_posts_on_latest_com_post_version_id       (latest_com_post_version_id) UNIQUE
#  index_com_posts_on_permalink                        (permalink) UNIQUE
#  index_com_posts_on_public_id                        (public_id) UNIQUE
#  index_com_posts_on_published_at_and_expires_at      (published_at,expires_at)
#
# Foreign Keys
#
#  fk_rails_...  (com_post_status_id => com_post_statuses.id)
#  fk_rails_...  (latest_com_post_revision_id => com_post_revisions.id) ON DELETE => nullify
#  fk_rails_...  (latest_com_post_version_id => com_post_versions.id) ON DELETE => nullify
#
class ComPost < ComPublisherRecord
  include PublicId
  include PublisherPostDocument

  belongs_to :author_avatar, class_name: "Avatar", inverse_of: false
  belongs_to :com_post_status, class_name: "ComPostStatus", inverse_of: :com_posts
  belongs_to :latest_version_record,
             class_name: "ComPostVersion",
             foreign_key: :latest_com_post_version_id,
             inverse_of: :latest_post,
             optional: true
  belongs_to :latest_revision_record,
             class_name: "ComPostRevision",
             foreign_key: :latest_com_post_revision_id,
             inverse_of: :latest_post,
             optional: true

  has_many :com_post_reviews, class_name: "ComPostReview", dependent: :restrict_with_error, inverse_of: :com_post
  has_many :com_post_versions, class_name: "ComPostVersion", dependent: :delete_all, inverse_of: :com_post
  has_many :com_post_revisions, class_name: "ComPostRevision", dependent: :delete_all, inverse_of: :com_post
  has_many :com_post_taggings, class_name: "ComPostTagging", dependent: :delete_all, inverse_of: :com_post
  has_many :com_post_tags, through: :com_post_taggings, source: :com_post_tag
  has_one :com_post_categorization, class_name: "ComPostCategorization", dependent: :delete, inverse_of: :com_post
  has_one :com_post_category, through: :com_post_categorization, source: :com_post_category

  validates :public_id, presence: true, uniqueness: true
  validates :body, presence: true
  validates :created_by_actor_id, presence: true
  validates :latest_com_post_version_id, :latest_com_post_revision_id, uniqueness: { allow_nil: true }

  def latest_version
    com_post_versions.order(created_at: :desc).first!
  end

  def latest_revision
    com_post_revisions.order(created_at: :desc).first!
  end
end
