# frozen_string_literal: true

require "test_helper"

# The staff CMS reaches one physical content family per controller, and the entry class it declares
# is the only thing that decides which family. These tests hold that boundary: a query built for
# docs/app must never see a docs/com or news/app row, whatever public id it is handed.
class PublishingManagementEntriesQueryTest < ActiveSupport::TestCase
  def query(audience:, surface:)
    PublishingManagementEntriesQuery.new(entry_class: publishing_entry_class(audience:, surface:))
  end

  test "call lists the family's entries newest first" do
    older = publishing_draft(audience: "app", surface: "docs", slug: "older", title: "Older")
    newer = publishing_draft(audience: "app", surface: "docs", slug: "newer", title: "Newer")
    older.update!(updated_at: 2.days.ago)
    newer.update!(updated_at: 1.hour.ago)

    assert_equal [newer, older], query(audience: "app", surface: "docs").call.to_a
  end

  test "call includes drafts and archived entries, because staff manage both" do
    draft = publishing_draft(audience: "app", surface: "docs", slug: "draft", title: "Draft")
    archived = publishing_draft(audience: "app", surface: "docs", slug: "archived", title: "Archived")
    archived.update!(archived_at: Time.current, archive_reason: "withdrawn")

    result = query(audience: "app", surface: "docs").call

    assert_includes result, draft
    assert_includes result, archived
  end

  test "call does not reach another family's table" do
    docs_app = publishing_draft(audience: "app", surface: "docs", slug: "docs-app", title: "Docs App")
    publishing_draft(audience: "com", surface: "docs", slug: "docs-com", title: "Docs Com")
    publishing_draft(audience: "app", surface: "news", slug: "news-app", title: "News App")

    assert_equal [docs_app], query(audience: "app", surface: "docs").call.to_a
  end

  test "find! returns the entry with its current revision, canonical slug and publication loaded" do
    entry = publishing_publish(
      entry: publishing_draft(audience: "app", surface: "docs", slug: "loaded", title: "Loaded"),
    )

    found = query(audience: "app", surface: "docs").find!(public_id: entry.public_id)

    assert_equal entry, found
    assert_predicate found.association(:current_revision), :loaded?
    assert_predicate found.association(:canonical_slug), :loaded?
    assert_predicate found.association(:active_publication), :loaded?
    assert_equal "loaded", found.canonical_slug.slug
  end

  # The class-level entry point is how a caller reaches the list without holding an instance.
  test "the class-level call is the same listing as the instance" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "class-level", title: "Class level")

    assert_equal(
      [entry],
      PublishingManagementEntriesQuery.call(entry_class: publishing_entry_class(audience: "app", surface: "docs")).to_a,
    )
  end

  test "find! raises rather than answering nil for an unknown public id" do
    assert_raises(ActiveRecord::RecordNotFound) do
      query(audience: "app", surface: "docs").find!(public_id: "0" * 21)
    end
  end

  # A public id is only unique within its own family's table, so the same string can name a real
  # entry in two families. Reaching one family's CMS with another family's id has to be a 404, not
  # a read across the boundary.
  test "find! refuses a public id that belongs to another family" do
    other = publishing_draft(audience: "com", surface: "docs", slug: "other-family", title: "Other")

    assert_raises(ActiveRecord::RecordNotFound) do
      query(audience: "app", surface: "docs").find!(public_id: other.public_id)
    end
  end

  # The public read path has always clamped its page size. This one ordered the whole family and
  # the controller built two URLs per row, so a cell that grew would be paid for on every index
  # render.
  test "page returns one page of the family and reports what follows it" do
    30.times do |index|
      entry = publishing_draft(audience: "app", surface: "docs", slug: "paged-#{index}", title: "Paged #{index}")
      entry.update!(updated_at: index.hours.ago)
    end

    first = query(audience: "app", surface: "docs").page(number: 1, per_page: 25)

    assert_equal 25, first.entries.length
    assert_equal 30, first.total
    assert_equal 1, first.number
    assert first.has_more

    second = query(audience: "app", surface: "docs").page(number: 2, per_page: 25)

    assert_equal 5, second.entries.length
    assert_not second.has_more
    assert_empty(first.entries.map(&:id) & second.entries.map(&:id))
  end

  test "page clamps a size outside the allowed range instead of honouring it" do
    3.times { |index| publishing_draft(audience: "app", surface: "docs", slug: "clamped-#{index}", title: "C#{index}") }

    assert_equal 1, query(audience: "app", surface: "docs").page(per_page: 0).entries.length
    assert_equal 3, query(audience: "app", surface: "docs").page(per_page: 10_000).entries.length
  end

  test "a page past the end is empty rather than an error" do
    publishing_draft(audience: "app", surface: "docs", slug: "only-one", title: "Only One")

    page = query(audience: "app", surface: "docs").page(number: 9, per_page: 25)

    assert_empty page.entries
    assert_not page.has_more
    assert_equal 1, page.total
  end

  test "page does not reach another family's table" do
    publishing_draft(audience: "app", surface: "docs", slug: "mine", title: "Mine")
    publishing_draft(audience: "com", surface: "docs", slug: "theirs", title: "Theirs")

    page = query(audience: "app", surface: "docs").page

    assert_equal 1, page.total
    assert_equal "Mine", page.entries.sole.current_revision.title
  end
end
