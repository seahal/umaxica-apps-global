# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_posts
# Database name: org_publisher
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
#  created_by_actor_id         :bigint           not null
#  latest_org_post_revision_id :bigint
#  latest_org_post_version_id  :bigint
#  org_post_status_id          :bigint           not null
#  public_id                   :string           not null
#  published_by_actor_id       :bigint
#
# Indexes
#
#  index_org_posts_on_author_avatar_id_and_created_at  (author_avatar_id,created_at DESC)
#  index_org_posts_on_latest_org_post_revision_id      (latest_org_post_revision_id) UNIQUE
#  index_org_posts_on_latest_org_post_version_id       (latest_org_post_version_id) UNIQUE
#  index_org_posts_on_org_post_status_id               (org_post_status_id)
#  index_org_posts_on_permalink                        (permalink) UNIQUE
#  index_org_posts_on_public_id                        (public_id) UNIQUE
#  index_org_posts_on_published_at_and_expires_at      (published_at,expires_at)
#
# Foreign Keys
#
#  fk_rails_...  (latest_org_post_revision_id => org_post_revisions.id) ON DELETE => nullify
#  fk_rails_...  (latest_org_post_version_id => org_post_versions.id) ON DELETE => nullify
#  fk_rails_...  (org_post_status_id => org_post_statuses.id)
#
class OrgPost < OrgPublisherRecord
  include PublicId
  include PublisherPostDocument

  belongs_to :author_avatar, class_name: "Avatar", inverse_of: false
  belongs_to :org_post_status, class_name: "OrgPostStatus", inverse_of: :org_posts
  belongs_to :latest_version_record,
             class_name: "OrgPostVersion",
             foreign_key: :latest_org_post_version_id,
             inverse_of: :latest_post,
             optional: true
  belongs_to :latest_revision_record,
             class_name: "OrgPostRevision",
             foreign_key: :latest_org_post_revision_id,
             inverse_of: :latest_post,
             optional: true

  has_many :org_post_reviews, class_name: "OrgPostReview", dependent: :restrict_with_error, inverse_of: :org_post
  has_many :org_post_versions, class_name: "OrgPostVersion", dependent: :delete_all, inverse_of: :org_post
  has_many :org_post_revisions, class_name: "OrgPostRevision", dependent: :delete_all, inverse_of: :org_post
  has_many :org_post_tags, class_name: "OrgPostTag", dependent: :delete_all, inverse_of: :org_post
  has_many :org_post_tag_masters, through: :org_post_tags, source: :org_post_tag_master
  has_one :org_post_category, class_name: "OrgPostCategory", dependent: :delete, inverse_of: :org_post
  has_one :org_post_category_master, through: :org_post_category, source: :org_post_category_master

  validates :public_id, presence: true, uniqueness: true
  validates :body, presence: true
  validates :created_by_actor_id, presence: true
  validates :latest_org_post_version_id, :latest_org_post_revision_id, uniqueness: { allow_nil: true }

  def latest_version
    org_post_versions.order(created_at: :desc).first!
  end

  def latest_revision
    org_post_revisions.order(created_at: :desc).first!
  end
end
