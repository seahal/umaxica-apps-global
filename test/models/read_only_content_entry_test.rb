# typed: false
# frozen_string_literal: true

require "test_helper"

class ReadOnlyContentEntryTest < ActiveSupport::TestCase
  test "validates status and slug shape" do
    entry = DocsAppContentEntry.new(
      slug: "Invalid Slug",
      locale: "jp",
      title: "Title",
      body: "Body",
      status: "unknown",
      published_at: Time.current,
    )

    assert_not entry.valid?
    assert_includes entry.errors.attribute_names, :slug
    assert_includes entry.errors.attribute_names, :status
  end

  test "published scope includes only currently published records" do
    visible = create_entry("visible", locale: "test-published", status: "published", published_at: 1.minute.ago)
    create_entry("draft", locale: "test-published", status: "draft", published_at: 1.minute.ago)
    create_entry("future", locale: "test-published", status: "published", published_at: 1.day.from_now)

    assert_equal [visible], DocsAppContentEntry.published.for_locale("test-published").to_a
  end

  test "published? returns true for published entry with published_at in the past" do
    entry = DocsAppContentEntry.new(status: "published", published_at: 1.minute.ago)

    assert_predicate entry, :published?

    entry_draft = DocsAppContentEntry.new(status: "draft", published_at: 1.minute.ago)

    assert_not entry_draft.published?

    entry_future = DocsAppContentEntry.new(status: "published", published_at: 1.day.from_now)

    assert_not entry_future.published?
  end

  private

  def create_entry(slug, locale:, status:, published_at:)
    DocsAppContentEntry.create!(
      slug: slug,
      locale: locale,
      title: slug.titleize,
      body: "Body",
      status: status,
      published_at: published_at,
    )
  end
end
