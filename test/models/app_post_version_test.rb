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
require "test_helper"

class AppPostVersionTest < ActiveSupport::TestCase
  setup do
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    handle = Handle.find_or_create_by!(handle: "post_version_test_handle") { |h| h.cooldown_until = Time.current }
    avatar =
      Avatar.find_or_create_by!(moniker: "AppPost Version Author") do |a|
        a.capability = capability
        a.active_handle = handle
      end
    status = AppPostStatus.find_or_create_by!(id: AppPostStatus::NOTHING)
    @post = AppPost.create!(
      author_avatar: avatar,
      app_post_status: status,
      body: "Valid post body content",
      created_by_actor_id: 1,
      permalink: "post-version-test-#{SecureRandom.hex(4)}",
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
    AppPostVersion.new(
      {
        app_post: @post,
        body: "Version body",
        permalink: "version-#{SecureRandom.hex(4)}",
        response_mode: "html",
        publish_at: Time.current,
        expires_at: 1.year.from_now,
      }.merge(attributes),
    )
  end
end
