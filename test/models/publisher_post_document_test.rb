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
      Avatar.find_or_create_by!(moniker: "Publisher AppPost Author") do |record|
        record.capability = capability
        record.active_handle = handle
      end
  end

  test "app post carries document-style publication fields" do
    post = create_post(AppPost, AppPostStatus)

    assert_predicate post, :persisted?
    assert_not_empty post.permalink
    assert_not_empty post.revision_key
    assert_predicate post, :html_response_mode?
    assert_includes AppPost.available, post
  end

  test "permalink validation rejects slash accepts underscore and rejects long length" do
    invalid = build_post(AppPost, AppPostStatus, permalink: "bad/slug")

    assert_not invalid.valid?

    valid = build_post(AppPost, AppPostStatus, permalink: "good_slug")

    assert_predicate valid, :valid?

    too_long = build_post(AppPost, AppPostStatus, permalink: "a" * 201)

    assert_not too_long.valid?
  end

  test "generated permalink is valid when public id starts with a hyphen" do
    post = build_post(AppPost, AppPostStatus, public_id: "-#{SecureRandom.alphanumeric(20)}")

    assert_predicate post, :valid?
    assert_match(/\A[A-Za-z0-9_][A-Za-z0-9_-]{0,199}\z/, post.permalink)
  end

  test "available scope excludes future and expired posts" do
    now = Time.current
    available = create_post(
      AppPost, AppPostStatus, permalink: "available_#{SecureRandom.hex(4)}",
                              published_at: now - 1.hour, expires_at: now + 1.hour,
    )
    future = create_post(
      AppPost, AppPostStatus, permalink: "future_#{SecureRandom.hex(4)}",
                              published_at: now + 1.hour, expires_at: now + 2.hours,
    )
    expired = create_post(
      AppPost, AppPostStatus, permalink: "expired_#{SecureRandom.hex(4)}",
                              published_at: now - 2.hours, expires_at: now - 1.hour,
    )

    available_ids = AppPost.available.pluck(:id)

    assert_includes available_ids, available.id
    assert_not_includes available_ids, future.id
    assert_not_includes available_ids, expired.id
  end

  test "redirect url is required when response mode is redirect" do
    invalid = build_post(AppPost, AppPostStatus, response_mode: "redirect", redirect_url: nil)

    assert_not invalid.valid?

    valid = build_post(AppPost, AppPostStatus, response_mode: "redirect", redirect_url: "https://example.com")

    assert_predicate valid, :valid?
  end

  test "response mode only accepts known values" do
    post = build_post(AppPost, AppPostStatus, response_mode: "xml")

    assert_not post.valid?
    assert_not_empty post.errors[:response_mode]
  end

  test "post versions and revisions enforce response mode constraints" do
    post = create_post(AppPost, AppPostStatus)

    invalid_version = AppPostVersion.new(version_attributes(post, "invalid-version").merge(response_mode: "xml"))
    invalid_revision = AppPostRevision.new(
      version_attributes(
        post,
        "invalid-revision",
      ).merge(response_mode: "redirect"),
    )

    assert_not invalid_version.valid?
    assert_not_empty invalid_version.errors[:response_mode]
    assert_not invalid_revision.valid?
    assert_not_empty invalid_revision.errors[:redirect_url]
  end

  test "published at must be before expires at" do
    post = build_post(AppPost, AppPostStatus, published_at: 1.day.from_now, expires_at: 1.day.ago)

    assert_not post.valid?
    assert_not_empty post.errors[:published_at]
  end

  test "revision key is ensured before validation" do
    post = build_post(AppPost, AppPostStatus, revision_key: nil)

    assert_predicate post, :valid?
    assert_not_empty post.revision_key
  end

  test "app post relates app_post_categorization and tags through tree masters" do
    post = create_post(AppPost, AppPostStatus)
    app_post_category = AppPostCategory.create!(id: 10, parent_id: AppPostCategory::NOTHING)
    app_post_tag = AppPostTag.create!(id: 11, parent_id: AppPostTag::NOTHING)

    app_post_categorization = AppPostCategorization.create!(app_post: post, app_post_category: app_post_category)
    app_post_tagging = AppPostTagging.create!(app_post: post, app_post_tag: app_post_tag)

    assert_equal app_post_categorization, post.app_post_categorization
    assert_equal app_post_category, post.app_post_category
    assert_includes post.app_post_taggings, app_post_tagging
    assert_includes post.app_post_tags, app_post_tag
  end

  test "post app_post_categorization and tag masters expose root and child hierarchy" do
    root_category = AppPostCategory.create!(id: 20, parent_id: AppPostCategory::NOTHING)
    child_category = AppPostCategory.create!(id: 21, parent: root_category)
    root_tag = AppPostTag.create!(id: 22, parent_id: AppPostTag::NOTHING)
    child_tag = AppPostTag.create!(id: 23, parent: root_tag)

    assert_predicate root_category, :root?
    assert_equal root_category, child_category.parent
    assert_includes root_category.children, child_category
    assert_predicate root_tag, :root?
    assert_equal root_tag, child_tag.parent
    assert_includes root_tag.children, child_tag
  end

  test "app post relates versions and revisions separately" do
    post = create_post(AppPost, AppPostStatus)
    version = AppPostVersion.create!(version_attributes(post, "current-version"))
    revision = AppPostRevision.create!(version_attributes(post, "current-revision"))

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
      "#{post_class.model_name.singular}_status": status,
      body: "Document-shaped post body",
      created_by_actor_id: 1,
      **attributes,
    )
  end

  def version_attributes(post, permalink)
    {
      post.model_name.singular.to_sym => post,
      :body => "Versioned body",
      :permalink => permalink,
      :response_mode => "html",
      :publish_at => 1.hour.ago,
      :expires_at => 1.year.from_now,
    }
  end
end
