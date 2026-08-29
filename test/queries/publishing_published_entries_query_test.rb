# frozen_string_literal: true

require "test_helper"

class PublishingPublishedEntriesQueryTest < ActiveSupport::TestCase
  # Seven statements: entries, canonical slugs, publications, versions, one per
  # version taxonomy assignment table, and the surface's vocabularies. All are
  # per-request, so the count stays flat as the number of entries grows -- which
  # is what this guards.
  EXPECTED_INDEX_QUERIES = 7

  test "returns only entries with an active publication" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")

    published_entry = publishing_publish(entry: publishing_draft(edition:, slug: "published-one", title: "Published"))
    draft_entry = publishing_draft(edition:, slug: "draft-one", title: "Draft")

    result = PublishingPublishedEntriesQuery.call(edition:)

    assert_includes result, published_entry
    assert_not_includes result, draft_entry
  end

  test "excludes an archived entry even while its publication window is open" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    entry = publishing_publish(entry: publishing_draft(edition:, slug: "archived-one", title: "Archived"))

    assert_includes PublishingPublishedEntriesQuery.call(edition:), entry

    entry.update!(archived_at: Time.current, archive_reason: "withdrawn")

    assert_not_includes PublishingPublishedEntriesQuery.call(edition:), entry
    assert_nil PublishingPublishedEntriesQuery.new(edition:).find_by(slug: "archived-one")
  end

  test "excludes a cancelled publication" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    entry = publishing_draft(edition:, slug: "cancelled-one", title: "Cancelled")
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    Publishing::Publication.create!(
      entry:, entry_version: version, effective_from: 1.hour.from_now,
      cancelled_at: Time.current, cancellation_reason: "pulled before going live",
    )

    assert_not_includes PublishingPublishedEntriesQuery.call(edition:), entry
  end

  test "a terminated publication stops being served once its window closes" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    entry = publishing_draft(edition:, slug: "terminated-one", title: "Terminated")
    version = Publishing::PromoteRevisionOperation.call(revision: entry.current_revision)
    terminated_at = 1.minute.ago
    Publishing::Publication.create!(
      entry:, entry_version: version, effective_from: 2.hours.ago, effective_until: terminated_at,
      terminated_at:, termination_reason: "superseded",
    )

    assert_not_includes PublishingPublishedEntriesQuery.call(edition:), entry
  end

  test "resolves canonical slugs only" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    entry = publishing_publish(entry: publishing_draft(edition:, slug: "canonical-one", title: "Canonical"))
    Publishing::EntrySlug.create!(
      entry:, edition:, locale: "ja", slug: "redirect-one", state: "redirect",
      canonicalized_at: 2.days.ago, redirected_at: 1.day.ago,
    )
    query = PublishingPublishedEntriesQuery.new(edition:)

    assert_equal entry, query.find_by(slug: "canonical-one")
    assert_nil query.find_by(slug: "redirect-one")
  end

  test "find_by_slug returns nil for an entry without an active publication" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    publishing_draft(edition:, slug: "no-publication", title: "No Publication")

    query = PublishingPublishedEntriesQuery.new(edition:)

    assert_nil query.find_by(slug: "no-publication")
  end

  test "filters by the published version's category and tag slugs" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    tag = publishing_tag_vocabulary(audience: "app", surface: "info")
    guide = publishing_term(vocabulary: category, locale: "ja", slug: "guide")
    ruby = publishing_term(vocabulary: tag, locale: "ja", slug: "ruby")

    tagged = publishing_draft(edition:, slug: "tagged-entry", title: "Tagged")
    Publishing::RevisionSingleTaxonomyAssignment.create!(
      entry_revision: tagged.current_revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: guide, locale: "ja",
    )
    Publishing::RevisionMultipleTaxonomyAssignment.create!(
      entry_revision: tagged.current_revision, vocabulary: tag, vocabulary_kind: tag.kind,
      taxonomy_term: ruby, locale: "ja", position: 0,
    )
    publishing_publish(entry: tagged)
    plain = publishing_publish(entry: publishing_draft(edition:, slug: "plain-entry", title: "Plain"))

    assert_equal [tagged], PublishingPublishedEntriesQuery.call(edition:, category: "guide").to_a
    assert_equal [tagged], PublishingPublishedEntriesQuery.call(edition:, tag: "ruby").to_a
    assert_includes PublishingPublishedEntriesQuery.call(edition:), plain
  end

  test "an unknown filter term returns no entries rather than falling back" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    publishing_publish(entry: publishing_draft(edition:, slug: "plain-one", title: "Plain"))

    assert_empty PublishingPublishedEntriesQuery.call(edition:, category: "never-existed").to_a
    assert_empty PublishingPublishedEntriesQuery.call(edition:, tag: "never-existed").to_a
  end

  test "filters follow the published snapshot, not the live term" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    term = publishing_term(vocabulary: category, locale: "ja", slug: "old-name")

    entry = publishing_draft(edition:, slug: "renamed-entry", title: "Renamed")
    Publishing::RevisionSingleTaxonomyAssignment.create!(
      entry_revision: entry.current_revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: term, locale: "ja",
    )
    publishing_publish(entry:)

    term.update!(slug: "new-name", name: "New Name")

    # A URL built from the published JSON keeps working, and the new name does
    # not retroactively match content published under the old one.
    assert_equal [entry], PublishingPublishedEntriesQuery.call(edition:, category: "old-name").to_a
    assert_empty PublishingPublishedEntriesQuery.call(edition:, category: "new-name").to_a

    # Archiving the live term does not unpublish what was already published, so
    # the published snapshot stays findable by the slug the response emits.
    term.update!(archived_at: Time.current, archive_reason: "retired")

    assert_equal [entry], PublishingPublishedEntriesQuery.call(edition:, category: "old-name").to_a
  end

  test "a category filter matches exactly and does not select descendants" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    parent = publishing_term(vocabulary: category, locale: "ja", slug: "parent")
    child = publishing_term(vocabulary: category, locale: "ja", slug: "child", parent:)

    entry = publishing_draft(edition:, slug: "child-entry", title: "Child")
    Publishing::RevisionSingleTaxonomyAssignment.create!(
      entry_revision: entry.current_revision, vocabulary: category, vocabulary_kind: category.kind,
      taxonomy_term: child, locale: "ja",
    )
    publishing_publish(entry:)

    assert_equal [entry], PublishingPublishedEntriesQuery.call(edition:, category: "child").to_a
    assert_empty PublishingPublishedEntriesQuery.call(edition:, category: "parent").to_a
  end

  test "a draft-only assignment never makes an entry findable by filter" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")
    category = publishing_category_vocabulary(audience: "app", surface: "info")
    term = publishing_term(vocabulary: category, locale: "ja", slug: "draft-only")

    entry = publishing_publish(entry: publishing_draft(edition:, slug: "later-tagged", title: "Later Tagged"))
    revision = publishing_revision(entry:, title: "Later Tagged v2", sequence: 2)
    Publishing::RevisionSingleTaxonomyAssignment.create!(
      entry_revision: revision, vocabulary: category, vocabulary_kind: category.kind, taxonomy_term: term, locale: "ja",
    )
    entry.update!(current_revision: revision)

    assert_empty PublishingPublishedEntriesQuery.call(edition:, category: "draft-only").to_a
  end

  test "serializing a published index uses a fixed number of queries" do
    edition = publishing_edition(audience: "app", surface: "info", locale: "ja")

    3.times { |index| publishing_publish(entry: publishing_draft(edition:, slug: "query-count-#{index}", title: "Title #{index}")) }

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
      # Mirrors the controller: the surface's vocabularies are loaded once and
      # shared across every entry in the response.
      vocabularies = Publishing::Vocabulary.available.for_scope(audience: "app", surface: "info").order(:key).to_a
      entries =
        PublishingPublishedEntriesQuery.call(edition:).map { |entry|
          PublishingEntrySerializer.call(entry:, namespace: :info, surface: :app, vocabularies:)
        }
    end

    assert_equal 3, entries.size
    assert_operator queries.size, :<=, EXPECTED_INDEX_QUERIES, queries.join("\n")
  end
end
