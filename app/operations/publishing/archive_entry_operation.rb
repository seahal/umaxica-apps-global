# typed: false
# frozen_string_literal: true

module Publishing
  # Archives an entry. `archived_at` is the only removal this schema has:
  # every association off an entry is `dependent: :restrict_with_exception`
  # and revisions, versions, and publications are the record of what was
  # published, so an entry is never deleted.
  #
  # A published entry is refused rather than silently hidden. The public read
  # path filters on `archived_at IS NULL` (`PublishingPublishedEntriesQuery`),
  # so archiving alone would drop a live URL while leaving an active
  # publication row claiming it is published -- two answers to one question.
  # Ending the publication first is the same order a reader sees.
  class ArchiveEntryOperation < ApplicationService
    def initialize(entry:, reason:, operator_public_id:)
      super()
      @entry = entry
      @reason = reason
      @operator_public_id = operator_public_id
    end

    def call
      entry.with_lock do
        next PublishingArchiveEntryResult.failure(base: "entry is already archived") if entry.archived?

        if entry.publications.active.exists?
          next PublishingArchiveEntryResult.failure(
            base: "a published entry cannot be archived; end its publication first",
          )
        end

        entry.update!(
          archived_at: Time.current,
          archive_reason: reason,
          archived_by_operator_public_id: operator_public_id,
        )
        PublishingArchiveEntryResult.success(entry)
      end
    end

    private

    attr_reader :entry, :reason, :operator_public_id
  end
end
