# frozen_string_literal: true

require "test_helper"

module Publishing
  class SchemaAndModelsTest < ActiveSupport::TestCase
    OBSOLETE = %w(
      publishing_editions
      publishing_entries
      publishing_entry_slugs
      publishing_entry_revisions
      publishing_entry_versions
      publishing_publications
      publishing_vocabularies
      publishing_taxonomy_terms
      publishing_media_usages
    ).freeze

    test "obsolete generic lifecycle tables are absent" do
      OBSOLETE.each do |table|
        assert_not PublishingRecord.connection.table_exists?(table), "expected #{table} to be gone"
      end
    end

    test "all twelve family table sets and global media files exist" do
      assert PublishingRecord.connection.table_exists?("publishing_media_files")
      Publishing::ContentFamilies::ENTRY_CLASSES.each do |klass|
        prefix = klass.table_name.delete_suffix("_entries")
        %w(
          entries entry_slugs entry_revisions entry_versions publications
          vocabularies taxonomy_terms
          revision_single_taxonomy_assignments revision_multiple_taxonomy_assignments
          version_single_taxonomy_assignments version_multiple_taxonomy_assignments
          revision_media_usages version_media_usages
        ).each do |suffix|
          table = "#{prefix}_#{suffix}"

          assert PublishingRecord.connection.table_exists?(table), "expected #{table}"
        end
      end
    end

    test "family tables do not store audience or surface ownership columns" do
      %w(
        publishing_docs_app_entries
        publishing_docs_app_entry_revisions
        publishing_docs_app_vocabularies
      ).each do |table|
        names = PublishingRecord.connection.columns(table).map(&:name)

        assert_not_includes names, "audience"
        assert_not_includes names, "surface"
      end
    end

    test "builds a docs/app lifecycle without an edition" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "sample-entry", title: "Sample")
      version = PromoteRevisionOperation.call(revision: entry.current_revision)
      publication = entry.publications.create!(entry_version: version, effective_from: 1.day.ago)

      assert_not publication.cancelled?
      assert_includes entry.publications.merge(entry.publications.klass.active), publication
    end

    test "entry versions are immutable after creation" do
      entry = publishing_draft(audience: "com", surface: "docs", slug: "imm", title: "T")
      version = PromoteRevisionOperation.call(revision: entry.current_revision)

      assert_raises(ActiveRecord::ReadOnlyRecord) { version.update!(title: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { version.destroy! }
    end

    test "publications reject overlapping windows for the same entry" do
      entry = publishing_draft(audience: "org", surface: "help", slug: "overlap", title: "T")
      version = PromoteRevisionOperation.call(revision: entry.current_revision)
      entry.publications.create!(entry_version: version, effective_from: 2.days.ago, effective_until: 1.day.ago)

      assert_raises(ActiveRecord::StatementInvalid) {
        entry.publications.create!(entry_version: version, effective_from: 36.hours.ago)
      }
    end
  end
end
