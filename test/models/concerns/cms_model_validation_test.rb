# typed: false
# frozen_string_literal: true

require "test_helper"

class CmsModelValidationTest < ActiveSupport::TestCase
  test "media files validate metadata, dimensions, and immutable binary identity" do
    valid = AppInfoMediaFile.new(
      storage_key: "media/key",
      content_type: "image/png",
      byte_size: 12,
      digest_algorithm: "sha256",
      digest: "a" * 64,
      metadata: {},
    )

    assert_predicate valid, :valid?

    invalid_metadata = valid.dup
    invalid_metadata.metadata = "not-an-object"

    assert_not invalid_metadata.valid?
    assert_includes invalid_metadata.errors.attribute_names, :metadata

    invalid_dimensions = valid.dup
    invalid_dimensions.width = 100
    invalid_dimensions.height = nil

    assert_not invalid_dimensions.valid?
    assert_includes invalid_dimensions.errors.attribute_names, :base

    persisted = AppInfoMediaFile.create!(
      storage_key: "media/immutable",
      content_type: "image/png",
      byte_size: 12,
      digest_algorithm: "sha256",
      digest: "b" * 64,
      metadata: {},
    )
    persisted.storage_key = "media/changed"

    assert_not persisted.valid?
    assert_includes persisted.errors[:storage_key], "cannot be changed"
  end

  test "media usages require one owner and a complete presentation location" do
    post = AppInfoPost.new
    revision = AppInfoPostRevision.new(post: post)
    media_file = AppInfoMediaFile.new(
      storage_key: "media/usage",
      content_type: "image/png",
      byte_size: 12,
      digest_algorithm: "sha256",
      digest: "c" * 64,
      metadata: {},
    )

    valid = AppInfoMediaUsage.new(
      role: "hero",
      position: 0,
      post: post,
      post_revision: revision,
      media_file: media_file,
      field_path: "body.blocks.0.image",
      presentation_metadata: {},
    )

    assert_predicate valid, :valid?

    no_owner = valid.dup
    no_owner.post_revision = nil
    no_owner.post_version = nil

    assert_not no_owner.valid?
    assert_includes no_owner.errors.attribute_names, :base

    wrong_post = valid.dup
    wrong_post.post = AppInfoPost.new

    assert_not wrong_post.valid?
    assert_includes wrong_post.errors.attribute_names, :base

    archived_file = media_file.dup
    archived_file.archived_at = Time.current
    archived_file.archive_reason = "retired"
    archived_media = valid.dup
    archived_media.media_file = archived_file

    assert_not archived_media.valid?
    assert_includes archived_media.errors.attribute_names, :media_file

    missing_location = valid.dup
    missing_location.field_path = nil
    missing_location.block_path = nil

    assert_not missing_location.valid?
    assert_includes missing_location.errors.attribute_names, :field_path
  end

  test "categories enforce locale and parent hierarchy boundaries" do
    category = AppNewsCategory.new(locale: "ja", slug: "news", name: "News")

    assert_predicate category, :valid?
    assert_equal "news", category.normalized_name

    parent = AppNewsCategory.new(locale: "ja", slug: "parent", name: "Parent")
    child = AppNewsCategory.new(locale: "ja", slug: "child", name: "Child", parent: parent)

    assert_predicate child, :valid?

    category.parent = category

    assert_not category.valid?
    assert_includes category.errors.attribute_names, :parent

    different_locale = AppNewsCategory.new(locale: "en", slug: "english", name: "English", parent: parent)

    assert_not different_locale.valid?
    assert_includes different_locale.errors.attribute_names, :parent

    cycle_a = AppNewsCategory.new(locale: "ja", slug: "cycle-a", name: "Cycle A")
    cycle_b = AppNewsCategory.new(locale: "ja", slug: "cycle-b", name: "Cycle B", parent: cycle_a)
    cycle_a.parent = cycle_b

    assert_not cycle_a.valid?
    assert_includes cycle_a.errors.attribute_names, :parent
  end
end
