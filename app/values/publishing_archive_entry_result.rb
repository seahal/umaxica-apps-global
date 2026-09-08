# typed: false
# frozen_string_literal: true

# Outcome of Publishing::ArchiveEntryOperation and
# Publishing::UnarchiveEntryOperation.
#
# Expected domain failures: archiving an entry that is still published,
# archiving one that is already archived, and unarchiving one that is not.
class PublishingArchiveEntryResult
  def self.success(entry)
    new(ok: true, entry: entry, errors: {})
  end

  def self.failure(errors)
    new(ok: false, entry: nil, errors: errors)
  end

  attr_reader :entry, :errors

  def initialize(ok:, entry:, errors:)
    @ok = ok
    @entry = entry
    @errors = errors
  end

  def ok?
    @ok
  end
end
