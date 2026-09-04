# typed: false
# frozen_string_literal: true

# Outcome of Publishing::ReviseEntryOperation.
#
# Expected domain failures (invalid content, stale lock) are carried here.
# Missing configuration or unreachable dependencies raise.
class PublishingReviseEntryResult
  def self.success(revision)
    new(ok: true, revision: revision, errors: {})
  end

  def self.failure(errors)
    new(ok: false, revision: nil, errors: errors)
  end

  attr_reader :revision, :errors

  def initialize(ok:, revision:, errors:)
    @ok = ok
    @revision = revision
    @errors = errors
  end

  def ok?
    @ok
  end
end
