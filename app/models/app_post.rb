# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_posts
# Database name: app_publisher
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
#  app_post_status_id          :bigint           not null
#  author_avatar_id            :bigint           not null
#  created_by_actor_id         :bigint           not null
#  latest_app_post_revision_id :bigint
#  latest_app_post_version_id  :bigint
#  public_id                   :string           not null
#  published_by_actor_id       :bigint
#
# Indexes
#
#  index_app_posts_on_app_post_status_id               (app_post_status_id)
#  index_app_posts_on_author_avatar_id_and_created_at  (author_avatar_id,created_at DESC)
#  index_app_posts_on_latest_app_post_revision_id      (latest_app_post_revision_id) UNIQUE
#  index_app_posts_on_latest_app_post_version_id       (latest_app_post_version_id) UNIQUE
#  index_app_posts_on_permalink                        (permalink) UNIQUE
#  index_app_posts_on_public_id                        (public_id) UNIQUE
#  index_app_posts_on_published_at_and_expires_at      (published_at,expires_at)
#
# Foreign Keys
#
#  fk_rails_...  (app_post_status_id => app_post_statuses.id)
#  fk_rails_...  (latest_app_post_revision_id => app_post_revisions.id) ON DELETE => nullify
#  fk_rails_...  (latest_app_post_version_id => app_post_versions.id) ON DELETE => nullify
#
class AppPost < AppPublisherRecord
  include PublicId
  include PublisherPostDocument

  belongs_to :author_avatar, class_name: "Avatar", inverse_of: false
  belongs_to :app_post_status, class_name: "AppPostStatus", inverse_of: :app_posts
  belongs_to :latest_version_record,
             class_name: "AppPostVersion",
             foreign_key: :latest_app_post_version_id,
             inverse_of: :latest_post,
             optional: true
  belongs_to :latest_revision_record,
             class_name: "AppPostRevision",
             foreign_key: :latest_app_post_revision_id,
             inverse_of: :latest_post,
             optional: true

  has_many :app_post_reviews, class_name: "AppPostReview", dependent: :restrict_with_error, inverse_of: :app_post
  has_many :app_post_versions, class_name: "AppPostVersion", dependent: :delete_all, inverse_of: :app_post
  has_many :app_post_revisions, class_name: "AppPostRevision", dependent: :delete_all, inverse_of: :app_post
  has_many :app_post_tags, class_name: "AppPostTag", dependent: :delete_all, inverse_of: :app_post
  has_many :app_post_tag_masters, through: :app_post_tags, source: :app_post_tag_master
  has_one :app_post_category, class_name: "AppPostCategory", dependent: :delete, inverse_of: :app_post
  has_one :app_post_category_master, through: :app_post_category, source: :app_post_category_master

  validates :public_id, presence: true, uniqueness: true
  validates :body, presence: true
  validates :created_by_actor_id, presence: true
  validates :latest_app_post_version_id, :latest_app_post_revision_id, uniqueness: { allow_nil: true }

  def latest_version
    app_post_versions.order(created_at: :desc).first!
  end

  def latest_revision
    app_post_revisions.order(created_at: :desc).first!
  end
end
