# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: post_versions
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
#  index_post_versions_on_post_id_and_created_at  (post_id,created_at DESC)
#  index_post_versions_on_public_id               (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id) ON DELETE => cascade
#
require "test_helper"

class PostVersionTest < ActiveSupport::TestCase
  setup do
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    handle = Handle.find_or_create_by!(handle: "post_version_test_handle") { |h| h.cooldown_until = Time.current }
    avatar =
      Avatar.find_or_create_by!(moniker: "Post Version Author") do |a|
        a.capability = capability
        a.active_handle = handle
      end
    status = PostStatus.find_or_create_by!(id: PostStatus::NOTHING)
    @post = Post.create!(
      author_avatar: avatar,
      post_status: status,
      body: "Valid post body content",
      created_by_actor_id: 1,
    )
  end

  test "is valid with publish and expiry timestamps" do
    version = build_post_version

    assert_predicate version, :valid?
  end

  test "requires publish_at" do
    version = build_post_version(publish_at: nil)

    assert_not version.valid?
    assert_not_empty version.errors[:publish_at]
  end

  test "requires expires_at" do
    version = build_post_version(expires_at: nil)

    assert_not version.valid?
    assert_not_empty version.errors[:expires_at]
  end

  private

  def build_post_version(attributes = {})
    PostVersion.new(
      {
        post: @post,
        body: "Version body",
        permalink: "version-#{SecureRandom.hex(4)}",
        response_mode: "html",
        publish_at: Time.current,
        expires_at: 1.year.from_now,
      }.merge(attributes),
    )
  end
end
