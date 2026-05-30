# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_post_versions
# Database name: app_publisher
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
#  app_post_id    :bigint           not null
#  edited_by_id   :bigint
#  public_id      :string           default(""), not null
#
# Indexes
#
#  index_app_post_versions_on_app_post_id_and_created_at  (app_post_id,created_at DESC)
#  index_app_post_versions_on_public_id                   (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (app_post_id => app_posts.id) ON DELETE => cascade
#
class AppPostVersion < AppPublisherRecord
  include ::Version
  include ::PublicId

  belongs_to :app_post, class_name: "AppPost", inverse_of: :app_post_versions
  has_one :latest_post,
          class_name: "AppPost",
          foreign_key: :latest_app_post_version_id,
          dependent: :nullify,
          inverse_of: :latest_version_record

  validates :permalink, presence: true, length: { maximum: 200 }
  validates :response_mode, presence: true, inclusion: { in: PublisherPostDocument::RESPONSE_MODES }
  validates :publish_at, presence: true
  validates :expires_at, presence: true
  validates :redirect_url, presence: true, if: -> { response_mode == "redirect" }
end
