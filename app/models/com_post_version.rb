# typed: false
# frozen_string_literal: true

class ComPostVersion < ComPublisherRecord
  self.table_name = "post_versions"

  include ::Version
  include ::PublicId

  belongs_to :post, class_name: "ComPost", inverse_of: :post_versions
  has_one :latest_post,
          class_name: "ComPost",
          foreign_key: :latest_version_id,
          dependent: :nullify,
          inverse_of: :latest_version_record

  validates :permalink, presence: true, length: { maximum: 200 }
  validates :response_mode, presence: true
  validates :publish_at, presence: true
  validates :expires_at, presence: true
end
