# typed: false
# frozen_string_literal: true

module Publishing
  # Returns an archived entry to the active set. `chk_<cell>_ent_archive`
  # requires the timestamp and the reason to be set or cleared together, and
  # the operator who archived it is no longer a fact about the entry once it
  # is active again, so all three columns are cleared in one update.
  class UnarchiveEntryOperation < ApplicationService
    def initialize(entry:, operator_public_id:)
      super()
      @entry = entry
      @operator_public_id = operator_public_id
    end

    def call
      entry.with_lock do
        next PublishingArchiveEntryResult.failure(base: "entry is not archived") unless entry.archived?

        entry.update!(archived_at: nil, archive_reason: nil, archived_by_operator_public_id: nil)
        PublishingArchiveEntryResult.success(entry)
      end
    end

    private

    attr_reader :entry, :operator_public_id
  end
end
