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

require "test_helper"

class AppPostTest < ActiveSupport::TestCase
  setup do
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    @handle = Handle.find_or_create_by!(handle: "post_test_handle") { |h| h.cooldown_until = Time.current }
    @avatar =
      Avatar.find_or_create_by!(moniker: "AppPost Author") do |a|
        a.capability = @capability
        a.active_handle = @handle
      end
    @status =
      AppPostStatus.find_or_create_by!(id: AppPostStatus::NOTHING)
    @valid_attributes = {
      author_avatar: @avatar,
      app_post_status: @status,
      body: "Valid post body content",
      created_by_actor_id: "user-1",
      permalink: "post-test-#{SecureRandom.hex(4)}",
    }.freeze
  end

  test "valid post creation" do
    post = AppPost.new(@valid_attributes)

    assert_predicate post, :valid?
    assert post.save
    assert_not_nil post.public_id
  end

  test "body is invalid when nil" do
    post = AppPost.new(@valid_attributes.merge(body: nil))

    assert_not post.valid?
    assert_not_empty post.errors[:body]
  end

  test "body is invalid when empty" do
    post = AppPost.new(@valid_attributes.merge(body: ""))

    assert_not post.valid?
    assert_not_empty post.errors[:body]
  end

  test "body is invalid when only whitespace" do
    post = AppPost.new(@valid_attributes.merge(body: "   "))

    assert_not post.valid?
    assert_not_empty post.errors[:body]
  end

  test "public_id uniqueness" do
    AppPost.create!(@valid_attributes)
    duplicate = AppPost.new(@valid_attributes.merge(public_id: AppPost.last.public_id))

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:public_id]
  end

  test "public_id length maximum boundary" do
    post = AppPost.new(@valid_attributes.merge(public_id: "a" * 22))

    assert_not post.valid?
    assert_not_empty post.errors[:public_id]
  end

  test "association: belongs_to author_avatar" do
    post = AppPost.create!(@valid_attributes)

    assert_equal @avatar, post.author_avatar
  end

  test "association: belongs_to app_post_status" do
    post = AppPost.create!(@valid_attributes)

    assert_equal @status, post.app_post_status
  end

  test "association deletion: restriction by app_post_reviews" do
    post = AppPost.create!(@valid_attributes)
    # AppPostReview might require more fields, assuming basic creation works for now
    # Create status if not exists
    AppPostReviewStatus.find_or_create_by!(id: AppPostReviewStatus::PENDING)
    AppPostReview.create!(
      app_post: post, reviewer_actor_id: @avatar.id, app_post_review_status_id: AppPostReviewStatus::PENDING,
      decided_at: Time.current,
    )

    assert_not post.destroy
    assert_includes post.errors[:base], "app post reviewsが存在しているので削除できません"
  end

  test "latest_version returns the most recent post version" do
    post = AppPost.create!(@valid_attributes)

    # Create post versions with different timestamps
    AppPostVersion.create!(
      app_post: post,
      body: "First version",
      permalink: "first-version",
      response_mode: "html",
      publish_at: 3.days.ago,
      expires_at: 1.year.from_now,
      created_at: 3.days.ago,
    )

    AppPostVersion.create!(
      app_post: post,
      body: "Second version",
      permalink: "second-version",
      response_mode: "html",
      publish_at: 2.days.ago,
      expires_at: 1.year.from_now,
      created_at: 2.days.ago,
    )

    latest = AppPostVersion.create!(
      app_post: post,
      body: "Latest version",
      permalink: "latest-version",
      response_mode: "html",
      publish_at: 1.day.ago,
      expires_at: 1.year.from_now,
      created_at: 1.day.ago,
    )

    assert_equal latest, post.latest_version
    assert_equal "Latest version", post.latest_version.body
  end

  test "validates id is numeric" do
    # With bigint ID, length validation is irrelevant
    # Test that record with explicit id validates with all required fields
    record = AppPost.new(@valid_attributes.merge(id: 99))

    assert_predicate record, :valid?
    assert_kind_of Integer, record.id
  end
end
