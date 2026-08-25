# typed: false
# frozen_string_literal: true

module Publishing
  # Raised when a draft revision still assigns an archived vocabulary or term.
  # Restoring an old version deliberately allows archived terms into a draft, so
  # promotion is where an author must resolve them.
  #
  # `details` carries everything a future authoring UI needs to render the
  # conflict without issuing another query. This is an internal domain error,
  # not user-facing copy, so it carries a plain message rather than an I18n key.
  class ArchivedTaxonomyAssignmentError < StandardError
    # One entry per obsolete term. `term_public_id` may be an ancestor of the
    # assigned term: a category is unpublishable when any step of its breadcrumb
    # has been retired, and the author needs to see which one.
    Detail = Data.define(
      :vocabulary_key, :term_public_id, :term_slug, :revision_public_id,
      :assigned_term_public_id, :vocabulary_archived,
    )

    attr_reader :details

    def initialize(details)
      @details = details
      super(
        "publishing: revision #{details.first&.revision_public_id} assigns archived taxonomy terms: " \
        "#{details.map { |detail| "#{detail.vocabulary_key}/#{detail.term_slug}" }.join(", ")}",
      )
    end
  end
end
