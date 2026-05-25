# typed: false
# frozen_string_literal: true

class OrgPost < OrgPublisherRecord
  self.table_name = "posts"

  include PublicId
  include PublisherPostDocument

  belongs_to :author_avatar, class_name: "Avatar", inverse_of: false
  belongs_to :post_status, class_name: "OrgPostStatus", inverse_of: :posts
  belongs_to :latest_version_record,
             class_name: "OrgPostVersion",
             foreign_key: :latest_version_id,
             inverse_of: :latest_post,
             optional: true
  belongs_to :latest_revision_record,
             class_name: "OrgPostRevision",
             foreign_key: :latest_revision_id,
             inverse_of: :latest_post,
             optional: true

  has_many :post_reviews, class_name: "OrgPostReview", dependent: :restrict_with_error, inverse_of: :post
  has_many :post_versions, class_name: "OrgPostVersion", dependent: :delete_all, inverse_of: :post
  has_many :post_revisions, class_name: "OrgPostRevision", dependent: :delete_all, inverse_of: :post
  has_many :post_tags, class_name: "OrgPostTag", dependent: :delete_all, inverse_of: :post
  has_many :tag_masters, through: :post_tags, source: :post_tag_master
  has_one :category, class_name: "OrgPostCategory", dependent: :delete, inverse_of: :post
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
