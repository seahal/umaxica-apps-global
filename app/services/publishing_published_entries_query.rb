# typed: false
# frozen_string_literal: true

# Read-only query for currently published entries within an edition, ordered
# newest-published-first, matching ReadOnlyContentEntry#recent_first behavior.
class PublishingPublishedEntriesQuery < ApplicationService
  def initialize(edition:)
    super()
    @edition = edition
  end

  def call
    return Publishing::Entry.none unless edition

    # The publication-window exclusion constraint guarantees at most one active
    # publication per entry, so this join cannot duplicate rows and needs no distinct.
    edition.entries
      .joins(:publications)
      .merge(Publishing::Publication.active)
      .preload(:canonical_slug, active_publication: :entry_version)
      .strict_loading
      .order(Arel.sql("publishing_publications.effective_from DESC"), "publishing_entries.id DESC")
  end

  def find_by(slug:)
    return unless edition

    entry =
      edition.entry_slugs.canonical
        .includes(entry: [:canonical_slug, { active_publication: :entry_version }])
        .find_by(slug:)&.entry
    return unless entry
    return unless entry.active_publication

    entry
  end

  private

  attr_reader :edition
end
