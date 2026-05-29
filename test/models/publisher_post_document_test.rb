# typed: false
# frozen_string_literal: true

require "test_helper"

class PublisherPostDocumentTest < ActiveSupport::TestCase
  setup do
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    handle =
      Handle.find_or_create_by!(handle: "publisher_post_document_test") { |record|
        record.cooldown_until = Time.current
      }
    @avatar =
      Avatar.find_or_create_by!(moniker: "Publisher Post Author") do |record|
        record.capability = capability
        record.active_handle = handle
      end
  end

  test "app post carries document-style publication fields" do
    post = create_post(Post, PostStatus)

    assert_predicate post, :persisted?
    assert_not_empty post.permalink
    assert_not_empty post.revision_key
    assert_predicate post, :html_response_mode?
    assert_includes Post.available, post
  end

  test "permalink validation rejects slash accepts underscore and rejects long length" do
    invalid = build_post(Post, PostStatus, permalink: "bad/slug")

    assert_not invalid.valid?

    valid = build_post(Post, PostStatus, permalink: "good_slug")

    assert_predicate valid, :valid?

    too_long = build_post(Post, PostStatus, permalink: "a" * 201)

    assert_not too_long.valid?
  end

  test "generated permalink is valid when public id starts with a hyphen" do
    post = build_post(Post, PostStatus, public_id: "-#{SecureRandom.alphanumeric(20)}")

    assert_predicate post, :valid?
    assert_match(/\A[A-Za-z0-9_][A-Za-z0-9_-]{0,199}\z/, post.permalink)
  end

  test "available scope excludes future and expired posts" do
    now = Time.current
    available = create_post(
      Post, PostStatus, permalink: "available_#{SecureRandom.hex(4)}",
                        published_at: now - 1.hour, expires_at: now + 1.hour,
    )
    future = create_post(
      Post, PostStatus, permalink: "future_#{SecureRandom.hex(4)}",
                        published_at: now + 1.hour, expires_at: now + 2.hours,
    )
    expired = create_post(
      Post, PostStatus, permalink: "expired_#{SecureRandom.hex(4)}",
                        published_at: now - 2.hours, expires_at: now - 1.hour,
    )

    available_ids = Post.available.pluck(:id)

    assert_includes available_ids, available.id
    assert_not_includes available_ids, future.id
    assert_not_includes available_ids, expired.id
  end

  test "redirect url is required when response mode is redirect" do
    invalid = build_post(Post, PostStatus, response_mode: "redirect", redirect_url: nil)

    assert_not invalid.valid?

    valid = build_post(Post, PostStatus, response_mode: "redirect", redirect_url: "https://example.com")

    assert_predicate valid, :valid?
  end

  test "response mode only accepts known values" do
    post = build_post(Post, PostStatus, response_mode: "xml")

    assert_not post.valid?
    assert_not_empty post.errors[:response_mode]
  end

  test "post versions and revisions enforce response mode constraints" do
    post = create_post(Post, PostStatus)

    invalid_version = PostVersion.new(version_attributes(post, "invalid-version").merge(response_mode: "xml"))
    invalid_revision = PostRevision.new(version_attributes(post, "invalid-revision").merge(response_mode: "redirect"))

    assert_not invalid_version.valid?
    assert_not_empty invalid_version.errors[:response_mode]
    assert_not invalid_revision.valid?
    assert_not_empty invalid_revision.errors[:redirect_url]
  end

  test "published at must be before expires at" do
    post = build_post(Post, PostStatus, published_at: 1.day.from_now, expires_at: 1.day.ago)

    assert_not post.valid?
    assert_not_empty post.errors[:published_at]
  end

  test "revision key is ensured before validation" do
    post = build_post(Post, PostStatus, revision_key: nil)

    assert_predicate post, :valid?
    assert_not_empty post.revision_key
  end

  test "app post relates category and tags through tree masters" do
    post = create_post(Post, PostStatus)
    category_master = PostCategoryMaster.create!(id: 10, parent_id: PostCategoryMaster::NOTHING)
    tag_master = PostTagMaster.create!(id: 11, parent_id: PostTagMaster::NOTHING)

    category = PostCategory.create!(post: post, post_category_master: category_master)
    tag = PostTag.create!(post: post, post_tag_master: tag_master)

    assert_equal category, post.category
    assert_equal category_master, post.category_master
    assert_includes post.post_tags, tag
    assert_includes post.tag_masters, tag_master
  end

  test "post category and tag masters expose root and child hierarchy" do
    root_category = PostCategoryMaster.create!(id: 20, parent_id: PostCategoryMaster::NOTHING)
    child_category = PostCategoryMaster.create!(id: 21, parent: root_category)
    root_tag = PostTagMaster.create!(id: 22, parent_id: PostTagMaster::NOTHING)
    child_tag = PostTagMaster.create!(id: 23, parent: root_tag)

    assert_predicate root_category, :root?
    assert_equal root_category, child_category.parent
    assert_includes root_category.children, child_category
    assert_predicate root_tag, :root?
    assert_equal root_tag, child_tag.parent
    assert_includes root_tag.children, child_tag
  end

  test "app post relates versions and revisions separately" do
    post = create_post(Post, PostStatus)
    version = PostVersion.create!(version_attributes(post, "current-version"))
    revision = PostRevision.create!(version_attributes(post, "current-revision"))

    post.update!(latest_version_record: version, latest_revision_record: revision)

    assert_equal version, post.latest_version
    assert_equal revision, post.latest_revision
    assert_equal version, post.latest_version_record
    assert_equal revision, post.latest_revision_record
  end

  test "com and org posts keep separate publisher database connections" do
    com_post = create_post(ComPost, ComPostStatus)
    org_post = create_post(OrgPost, OrgPostStatus)

    assert_equal "com_publisher", com_post.class.connection_db_config.name
    assert_equal "org_publisher", org_post.class.connection_db_config.name
  end

  private

  def create_post(post_class, status_class, **attributes)
    post = build_post(post_class, status_class, **attributes)
    post.save!
    post
  end

  def build_post(post_class, status_class, **attributes)
    status = status_class.find_or_create_by!(id: status_class::NOTHING)
    post_class.new(
      author_avatar: @avatar,
      post_status: status,
      body: "Document-shaped post body",
      created_by_actor_id: 1,
      **attributes,
    )
  end

  def version_attributes(post, permalink)
    {
      post: post,
      body: "Versioned body",
      permalink: permalink,
      response_mode: "html",
      publish_at: 1.hour.ago,
      expires_at: 1.year.from_now,
    }
  end
end
