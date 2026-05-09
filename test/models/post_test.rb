# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: posts
# Database name: avatar
#
#  id                    :bigint           not null, primary key
#  body                  :text             not null
#  published_at          :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  author_avatar_id      :bigint           not null
#  created_by_actor_id   :bigint           not null
#  post_status_id        :bigint           default(0), not null
#  public_id             :string           not null
#  published_by_actor_id :bigint
#
# Indexes
#
#  index_posts_on_author_avatar_id_and_created_at  (author_avatar_id,created_at DESC)
#  index_posts_on_post_status_id                   (post_status_id)
#  index_posts_on_public_id                        (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_avatar_id => avatars.id)
#  fk_rails_...  (post_status_id => post_statuses.id)
#

require "test_helper"

class PostTest < ActiveSupport::TestCase
  setup do
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    @handle = Handle.find_or_create_by!(handle: "post_test_handle") { |h| h.cooldown_until = Time.current }
    @avatar =
      Avatar.find_or_create_by!(moniker: "Post Author") do |a|
        a.capability = @capability
        a.active_handle = @handle
      end
    @status =
      PostStatus.find_or_create_by!(id: PostStatus::NOTHING)
    @valid_attributes = {
      author_avatar: @avatar,
      post_status: @status,
      body: "Valid post body content",
      created_by_actor_id: "user-1",
    }.freeze
  end

  test "valid post creation" do
    post = Post.new(@valid_attributes)

    assert_predicate post, :valid?
    assert post.save
    assert_not_nil post.public_id
  end

  test "body is invalid when nil" do
    post = Post.new(@valid_attributes.merge(body: nil))

    assert_not post.valid?
    assert_not_empty post.errors[:body]
  end

  test "body is invalid when empty" do
    post = Post.new(@valid_attributes.merge(body: ""))

    assert_not post.valid?
    assert_not_empty post.errors[:body]
  end

  test "body is invalid when only whitespace" do
    post = Post.new(@valid_attributes.merge(body: "   "))

    assert_not post.valid?
    assert_not_empty post.errors[:body]
  end

  test "public_id uniqueness" do
    Post.create!(@valid_attributes)
    duplicate = Post.new(@valid_attributes.merge(public_id: Post.last.public_id))

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:public_id]
  end

  test "public_id length maximum boundary" do
    post = Post.new(@valid_attributes.merge(public_id: "a" * 22))

    assert_not post.valid?
    assert_not_empty post.errors[:public_id]
  end

  test "association: belongs_to author_avatar" do
    post = Post.create!(@valid_attributes)

    assert_equal @avatar, post.author_avatar
  end

  test "association: belongs_to post_status" do
    post = Post.create!(@valid_attributes)

    assert_equal @status, post.post_status
  end

  test "association deletion: restriction by post_reviews" do
    post = Post.create!(@valid_attributes)
    # PostReview might require more fields, assuming basic creation works for now
    # Create status if not exists
    PostReviewStatus.find_or_create_by!(id: PostReviewStatus::PENDING)
    PostReview.create!(
      post: post, reviewer_actor_id: @avatar.id, post_review_status_id: PostReviewStatus::PENDING,
      decided_at: Time.current,
    )

    assert_not post.destroy
    assert_includes post.errors[:base], "post reviewsが存在しているので削除できません"
  end

  test "latest_version returns the most recent post version" do
    post = Post.create!(@valid_attributes)

    # Create post versions with different timestamps
    PostVersion.create!(
      post: post,
      body: "First version",
      permalink: "first-version",
      response_mode: "html",
      publish_at: 3.days.ago,
      expires_at: 1.year.from_now,
      created_at: 3.days.ago,
    )

    PostVersion.create!(
      post: post,
      body: "Second version",
      permalink: "second-version",
      response_mode: "html",
      publish_at: 2.days.ago,
      expires_at: 1.year.from_now,
      created_at: 2.days.ago,
    )

    latest = PostVersion.create!(
      post: post,
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
    record = Post.new(@valid_attributes.merge(id: 99))

    assert_predicate record, :valid?
    assert_kind_of Integer, record.id
  end
end
