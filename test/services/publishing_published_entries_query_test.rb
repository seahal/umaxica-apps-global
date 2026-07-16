# frozen_string_literal: true

require "test_helper"

class PublishingPublishedEntriesQueryTest < ActiveSupport::TestCase
  test "returns only entries with an active publication" do
    edition = Publishing::Edition.create!(audience: "app", surface: "info", locale: "ja")

    published_entry = build_published_entry(edition:, slug: "published-one")
    draft_entry = Publishing::Entry.create!(edition:, locale: "ja")
    Publishing::EntrySlug.create!(entry: draft_entry, edition:, locale: "ja", slug: "draft-one", state: "canonical", canonicalized_at: Time.current)

    result = PublishingPublishedEntriesQuery.call(edition:)

    assert_includes result, published_entry
    assert_not_includes result, draft_entry
  end

  test "find_by_slug returns nil for an entry without an active publication" do
    edition = Publishing::Edition.create!(audience: "app", surface: "info", locale: "ja")
    Publishing::Entry.create!(edition:, locale: "ja").tap { |entry|
      Publishing::EntrySlug.create!(entry:, edition:, locale: "ja", slug: "no-publication", state: "canonical", canonicalized_at: Time.current)
    }

    query = PublishingPublishedEntriesQuery.new(edition:)

    assert_nil query.find_by(slug: "no-publication")
  end

  private

  def build_published_entry(edition:, slug:)
    entry = Publishing::Entry.create!(edition:, locale: "ja")
    Publishing::EntrySlug.create!(entry:, edition:, locale: "ja", slug:, state: "canonical", canonicalized_at: Time.current)
    revision =
      Publishing::EntryRevision.create!(
        entry:, locale: "ja", title: "T", body: { "text" => "hi" }, schema_version: 1,
        content_digest: "d" * 64, sequence: 1,
      )
    entry.update!(current_revision: revision)
    version =
      Publishing::EntryVersion.create!(
        entry:, entry_revision: revision, locale: "ja", title: "T", body: { "text" => "hi" },
        schema_version: 1, content_digest: "d" * 64, sequence: 1,
      )
    Publishing::Publication.create!(entry:, entry_version: version, effective_from: 1.hour.ago)
    entry
  end
end
