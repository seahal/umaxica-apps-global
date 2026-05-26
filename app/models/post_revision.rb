# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_revisions
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
class PostRevision < AppPostRevision
  belongs_to :post, class_name: "Post", inverse_of: :post_revisions
  has_one :latest_post,
          class_name: "Post",
          foreign_key: :latest_revision_id,
          dependent: :nullify,
          inverse_of: :latest_revision_record
end
