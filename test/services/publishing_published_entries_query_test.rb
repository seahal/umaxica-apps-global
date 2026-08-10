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

  test "serializing a published index uses a fixed number of queries" do
    edition = Publishing::Edition.create!(audience: "app", surface: "info", locale: "ja")

    3.times do |index|
      entry = Publishing::Entry.create!(edition:, locale: "ja")
      Publishing::EntrySlug.create!(
        entry:, edition:, locale: "ja", slug: "query-count-#{index}", state: "canonical", canonicalized_at: Time.current,
      )
      revision =
        Publishing::EntryRevision.create!(
          entry:, locale: "ja", title: "Title #{index}", body: { "text" => "body" }, schema_version: 1,
          content_digest: index.to_s.rjust(64, "0"), sequence: 1,
        )
      entry.update!(current_revision: revision)
      version =
        Publishing::EntryVersion.create!(
          entry:, entry_revision: revision, locale: "ja", title: "Title #{index}", body: { "text" => "body" },
          schema_version: 1, content_digest: (index + 10).to_s.rjust(64, "0"), sequence: 1,
        )
      Publishing::Publication.create!(entry:, entry_version: version, effective_from: 1.hour.ago)
    end

    queries = []
    subscriber =
      lambda do |*, payload|
        sql = payload[:sql]
        next if payload[:cached] || payload[:name] == "SCHEMA"
        next if sql.match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/)

        queries << sql
      end

    entries = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      entries =
        PublishingPublishedEntriesQuery.call(edition:).map { |entry|
          PublishingEntrySerializer.call(entry:, namespace: :info, surface: :app)
        }
    end

    assert_equal 3, entries.size
    assert_operator queries.size, :<=, 4, queries.join("\n")
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
