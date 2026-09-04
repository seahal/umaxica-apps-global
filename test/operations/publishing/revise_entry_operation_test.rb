# frozen_string_literal: true

require "test_helper"

module Publishing
  class ReviseEntryOperationTest < ActiveSupport::TestCase
    test "creates the next revision and leaves the previous revision unchanged" do
      edition = publishing_edition(audience: "app", surface: "docs", locale: "ja")
      entry = publishing_draft(edition:, slug: "guide", title: "Guide")
      previous = entry.current_revision
      previous_title = previous.title
      previous_body = previous.body.deep_dup

      result = ReviseEntryOperation.call(
        entry:,
        title: "Guide v2",
        summary: "Updated summary",
        body: { "text" => "Updated body" },
        lock_version: entry.lock_version,
      )

      assert_predicate result, :ok?
      entry.reload

      assert_equal result.revision, entry.current_revision
      assert_equal 2, result.revision.sequence
      assert_equal "Guide v2", result.revision.title
      assert_equal "Updated summary", result.revision.summary
      assert_equal({ "text" => "Updated body" }, result.revision.body)
      previous.reload

      assert_equal previous_title, previous.title
      assert_equal previous_body, previous.body
      assert_equal 1, previous.sequence
      assert_not_equal previous.content_digest, result.revision.content_digest
    end

    test "copies taxonomy assignments and media usages onto the new revision" do
      edition = publishing_edition(audience: "app", surface: "docs", locale: "ja")
      category = publishing_category_vocabulary(audience: "app", surface: "docs")
      tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      guide = publishing_term(vocabulary: category, locale: "ja", slug: "guide", name: "ガイド")
      ruby = publishing_term(vocabulary: tag, locale: "ja", slug: "ruby", name: "Ruby")
      rails = publishing_term(vocabulary: tag, locale: "ja", slug: "rails", name: "Rails")
      entry = publishing_draft(edition:, slug: "assigned", title: "Assigned")
      revision = entry.current_revision
      RevisionSingleTaxonomyAssignment.create!(
        entry_revision: revision, vocabulary_id: category.id, vocabulary_kind: category.kind,
        taxonomy_term_id: guide.id, locale: "ja",
      )
      RevisionMultipleTaxonomyAssignment.create!(
        entry_revision: revision, vocabulary_id: tag.id, vocabulary_kind: tag.kind,
        taxonomy_term_id: rails.id, locale: "ja", position: 0,
      )
      RevisionMultipleTaxonomyAssignment.create!(
        entry_revision: revision, vocabulary_id: tag.id, vocabulary_kind: tag.kind,
        taxonomy_term_id: ruby.id, locale: "ja", position: 1,
      )
      media_file = publishing_media_file
      publishing_revision_media_usage(revision:, media_file:, role: "hero")

      result = ReviseEntryOperation.call(
        entry:,
        title: "Assigned v2",
        summary: revision.summary,
        body: revision.body,
        lock_version: entry.lock_version,
      )

      next_revision = result.revision

      assert_equal guide.id, next_revision.single_taxonomy_assignments.sole.taxonomy_term_id
      assert_equal(
        [rails.id, ruby.id],
        next_revision.multiple_taxonomy_assignments.ordered.map(&:taxonomy_term_id),
      )
      usage = next_revision.media_usages.sole

      assert_equal media_file.id, usage.media_file_id
      assert_equal "hero", usage.role
      assert_equal 1, revision.media_usages.count
    end

    test "rejects a stale lock_version without creating a revision" do
      edition = publishing_edition(audience: "app", surface: "docs", locale: "ja")
      entry = publishing_draft(edition:, slug: "stale", title: "Stale")
      current = entry.current_revision

      result = ReviseEntryOperation.call(
        entry:,
        title: "Should not persist",
        summary: "no",
        body: { "text" => "no" },
        lock_version: entry.lock_version - 1,
      )

      assert_not result.ok?
      assert_equal current, entry.reload.current_revision
      assert_equal 1, entry.revisions.count
    end
  end
end
