# typed: false
# frozen_string_literal: true

class ComPostRevision < ComPublisherRecord
  self.table_name = "post_revisions"

  include ::Version
  include ::PublicId

  belongs_to :post, class_name: "ComPost", inverse_of: :post_revisions
  has_one :latest_post,
          class_name: "ComPost",
          foreign_key: :latest_revision_id,
          dependent: :nullify,
          inverse_of: :latest_revision_record

  validates :permalink, presence: true, length: { maximum: 200 }
  validates :response_mode, presence: true
  validates :publish_at, presence: true
  validates :expires_at, presence: true
end

