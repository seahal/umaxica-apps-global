# typed: false
# frozen_string_literal: true

# The opaque cursor for the published-entries collection.
#
# adr/api-collection-contract.md requires that the cursor "is never a raw offset, a primary key, or
# any value a client can construct or interpret". Two properties satisfy that here:
#
#   - The payload carries the publication instant and the entry's `public_id`. Neither is a database
#     primary key, so even a decoded cursor exposes nothing that
#     docs/reference/api-design-standards.md keeps off the wire.
#   - It is signed with `Rails.application.message_verifier`, following the precedent in
#     `SessionLimitResolutionTokenRef`, so a client cannot construct one. It is signed rather than
#     encrypted: the contents are already public, and signing is what makes forging impossible.
#
# The encoding may change without a version bump; that is the point of the cursor being opaque
# (adr/api-versioning-and-client-conventions.md).
class PublishingEntriesCursor
  PURPOSE = :publishing_entries_cursor

  # The sort key of PublishingPublishedEntriesQuery, in the same order. A cursor that did not match
  # the ORDER BY would silently skip or repeat rows.
  Position = Data.define(:effective_from, :entry_public_id)

  InvalidCursor = Class.new(StandardError)

  class << self
    # Returns nil when the entry has no active publication, which is the same condition under which
    # PublishingEntrySerializer renders nothing.
    def encode(entry)
      effective_from = entry.active_publication&.effective_from
      return nil unless effective_from

      verifier.generate({ "f" => effective_from.utc.iso8601(6), "p" => entry.public_id })
    end

    # Raises rather than returning nil for a cursor that does not verify. A malformed cursor is a
    # client error, and silently serving page one instead would hand back the wrong rows while
    # looking successful.
    def decode(value)
      payload = verifier.verify(value.to_s)
      effective_from = Time.zone.parse(payload.fetch("f").to_s)
      entry_public_id = payload.fetch("p").to_s
      raise InvalidCursor, "cursor carries no position" if effective_from.nil? || entry_public_id.empty?

      Position.new(effective_from:, entry_public_id:)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ArgumentError, TypeError => e
      raise InvalidCursor, "cursor did not verify: #{e.class}"
    end

    private

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
