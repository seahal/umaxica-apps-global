# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_revisions
# Database name: org_publisher
#
#  id             :bigint           not null, primary key
#  body           :text
#  description    :string
#  edited_by_type :string
#  expires_at     :datetime         not null
#  permalink      :string(200)      not null
#  publish_at     :datetime         not null
#  redirect_url   :string
#  response_mode  :string           not null
#  title          :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  edited_by_id   :bigint
#  post_id        :bigint           not null
#  public_id      :string           default(""), not null
#
# Indexes
#
#  index_post_revisions_on_post_id_and_created_at  (post_id,created_at DESC)
#  index_post_revisions_on_public_id               (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id) ON DELETE => cascade
#
class OrgPostRevision < OrgPublisherRecord
  self.table_name = "post_revisions"

  include ::Version
  include ::PublicId

  belongs_to :post, class_name: "OrgPost", inverse_of: :post_revisions
  has_one :latest_post,
          class_name: "OrgPost",
          foreign_key: :latest_revision_id,
          dependent: :nullify,
          inverse_of: :latest_revision_record

  validates :permalink, presence: true, length: { maximum: 200 }
  validates :response_mode, presence: true, inclusion: { in: PublisherPostDocument::RESPONSE_MODES }
  validates :publish_at, presence: true
  validates :expires_at, presence: true
  validates :redirect_url, presence: true, if: -> { response_mode == "redirect" }
end
