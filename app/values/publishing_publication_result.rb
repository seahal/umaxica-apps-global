# typed: false
# frozen_string_literal: true

# Outcome of the two operations that move an entry across the published
# boundary: Publishing::PublishEntryOperation and
# Publishing::EndPublicationOperation.
#
# Expected domain failures are the states a staff operator can reach from the
# CMS -- an archived entry, an entry with no revision to promote, a
# publication that has already ended, a requested window that overlaps one
# already recorded. A missing dependency or a violated invariant raises.
class PublishingPublicationResult
  def self.success(publication)
    new(ok: true, publication: publication, errors: {})
  end

  def self.failure(errors)
    new(ok: false, publication: nil, errors: errors)
  end

  attr_reader :publication, :errors

  def initialize(ok:, publication:, errors:)
    @ok = ok
    @publication = publication
    @errors = errors
  end

  def ok?
    @ok
  end
end
