# typed: false
# frozen_string_literal: true

# Read-only query for currently published entries within an edition, ordered
# newest-published-first.
#
# Taxonomy filters match the published version's snapshots, never a draft
# revision's assignments, so an entry is only findable by what it actually
# published. An unknown or archived filter term yields no entries rather than
# quietly falling back to the unfiltered list.
class PublishingPublishedEntriesQuery < ApplicationService
  def initialize(edition:, category: nil, tag: nil)
    super()
    @edition = edition
    @category = category.presence
    @tag = tag.presence
  end

  def call
    return Publishing::Entry.none unless edition

    scope = published_scope
    # `category` and `tag` are the deliberately narrow public filter allowlist,
    # but the query shape comes from each vocabulary's structural kind, not from
    # its name, so a future vocabulary of either kind needs no new branch here.
    scope = filter_by(scope, key: "category", slug: category) if category
    scope = filter_by(scope, key: "tag", slug: tag) if tag
    scope
      .preload(
        :canonical_slug,
        active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) },
      )
      .strict_loading
      .order(Arel.sql("publishing_publications.effective_from DESC"), "publishing_entries.id DESC")
  end

  def find_by(slug:)
    return unless edition

    entry =
      edition.entry_slugs.canonical
        .includes(
          entry: [
            :canonical_slug,
            { active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) } },
          ],
        )
        .find_by(slug:)&.entry
    return unless entry
    return if entry.archived?
    return unless entry.active_publication

    entry
  end

  private

  attr_reader :edition, :category, :tag

  # The publication-window exclusion constraint guarantees at most one active
  # publication per entry, so this join cannot duplicate rows and needs no
  # distinct. Archived entries stay unpublished even while a publication window
  # is still open.
  def published_scope
    edition.entries
      .where(archived_at: nil)
      .joins(:publications)
      .merge(Publishing::Publication.active)
  end

  def filter_by(scope, key:, slug:)
    vocabulary = filterable_vocabularies[key]
    # A filter naming a vocabulary this surface does not have matches nothing,
    # rather than being ignored.
    return scope.none unless vocabulary

    kind = vocabulary.structural_kind
    association = kind.ordered? ? :multiple_taxonomy_assignments : :single_taxonomy_assignments

    scope.where(
      Publishing::EntryVersion
        .where("publishing_entry_versions.id = publishing_publications.entry_version_id")
        .joins(association)
        .merge(matching_snapshots(kind.version_assignment_class, key:, slug:))
        .arel.exists,
    )
  end

  def filterable_vocabularies
    @filterable_vocabularies ||=
      Publishing::Vocabulary
        .available
        .for_scope(audience: edition.audience, surface: edition.surface)
        .index_by(&:key)
  end

  # Filters match the same frozen snapshots the response renders. A URL built
  # from published JSON therefore keeps working after the live term is renamed,
  # moved, or archived, and a term's new name never retroactively matches
  # content published under its old one. Matching is exact: a parent category
  # does not select its descendants.
  def matching_snapshots(assignment_class, key:, slug:)
    assignment_class.where(vocabulary_key_snapshot: key, term_slug_snapshot: slug, locale_snapshot: edition.locale)
  end
end
