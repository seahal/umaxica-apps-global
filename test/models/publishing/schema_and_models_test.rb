# frozen_string_literal: true

require "test_helper"

module Publishing
  class SchemaAndModelsTest < ActiveSupport::TestCase
    test "publishing tables exist only in the publishing database" do
      %w(
        publishing_editions
        publishing_entries
        publishing_entry_slugs
        publishing_entry_revisions
        publishing_entry_versions
        publishing_publications
        publishing_media_files
        publishing_media_usages
      ).each do |table|
        assert PublishingRecord.connection.table_exists?(table), "expected #{table} to exist"
      end
    end

    test "no taxonomy tables exist in the publishing schema" do
      %w(publishing_categories publishing_tags).each do |table|
        assert_not PublishingRecord.connection.table_exists?(table), "expected #{table} to not exist yet"
      end
    end

    test "builds a full entry lifecycle: edition -> entry -> revision -> version -> publication" do
      edition = Edition.create!(audience: "app", surface: "info", locale: "ja")
      entry = Entry.create!(edition:, locale: "ja")

      slug = EntrySlug.create!(entry:, edition:, locale: "ja", slug: "sample-entry", state: "canonical", canonicalized_at: Time.current)

      assert_equal "canonical", slug.state

      revision =
        EntryRevision.create!(
          entry:, locale: "ja", title: "Sample", body: { "text" => "hello" }, schema_version: 1,
          content_digest: "a" * 64, sequence: 1,
        )
      entry.update!(current_revision: revision)

      version =
        EntryVersion.create!(
          entry:, entry_revision: revision, locale: "ja", title: "Sample", body: { "text" => "hello" },
          schema_version: 1, content_digest: "a" * 64, sequence: 1,
        )

      publication = Publication.create!(entry:, entry_version: version, effective_from: 1.day.ago)

      assert_not publication.cancelled?
      assert_includes Publication.active, publication
    end

    test "an edition rejects an unknown audience or surface" do
      edition = Edition.new(audience: "nope", surface: "info", locale: "ja")

      assert_not edition.valid?

      edition = Edition.new(audience: "app", surface: "nope", locale: "ja")

      assert_not edition.valid?
    end

    test "entry versions are immutable after creation" do
      edition = Edition.create!(audience: "com", surface: "docs", locale: "ja")
      entry = Entry.create!(edition:, locale: "ja")
      revision =
        EntryRevision.create!(
          entry:, locale: "ja", title: "T", body: {}, schema_version: 1, content_digest: "b" * 64, sequence: 1,
        )
      version =
        EntryVersion.create!(
          entry:, entry_revision: revision, locale: "ja", title: "T", body: {}, schema_version: 1,
          content_digest: "b" * 64, sequence: 1,
        )

      assert_raises(ActiveRecord::ReadOnlyRecord) { version.update!(title: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { version.destroy! }
    end

    test "publications reject overlapping windows for the same entry" do
      edition = Edition.create!(audience: "org", surface: "help", locale: "ja")
      entry = Entry.create!(edition:, locale: "ja")
      revision =
        EntryRevision.create!(
          entry:, locale: "ja", title: "T", body: {}, schema_version: 1, content_digest: "c" * 64, sequence: 1,
        )
      version =
        EntryVersion.create!(
          entry:, entry_revision: revision, locale: "ja", title: "T", body: {}, schema_version: 1,
          content_digest: "c" * 64, sequence: 1,
        )
      Publication.create!(entry:, entry_version: version, effective_from: 2.days.ago, effective_until: 1.day.ago)

      assert_raises(ActiveRecord::StatementInvalid) {
        Publication.create!(entry:, entry_version: version, effective_from: 36.hours.ago)
      }
    end

    test "media usage requires exactly one entry owner" do
      usage = MediaUsage.new(entry_revision_id: 1, entry_version_id: 1)

      assert_not usage.valid?
      assert_includes usage.errors[:base], "must belong to exactly one of entry_revision or entry_version"
    end

    test "media usage accepts one entry owner" do
      usage = MediaUsage.new(entry_revision_id: 1)

      usage.valid?

      assert_empty usage.errors[:base]
    end
  end
end
