# typed: false
# frozen_string_literal: true

# SHA-256 hex digest of a Publishing revision's content snapshot.
#
# There was no production digest implementation; this is the application
# convention for a new EntryRevision created by ReviseEntryOperation.
#
# Input is the canonical JSON of:
#   schema_version, locale, title, summary, body
# with object keys sorted at every nesting level. Changing any of those
# fields changes the digest. Taxonomy assignments and media usages are
# stored as related rows and are not part of this snapshot.
class PublishingRevisionContentDigest
  SNAPSHOT_KEYS = %i(schema_version locale title summary body).freeze

  def self.call(...)
    new(...).call
  end

  def initialize(schema_version:, locale:, title:, summary:, body:)
    @schema_version = schema_version
    @locale = locale
    @title = title
    @summary = summary
    @body = body
  end

  def call
    Digest::SHA256.hexdigest(JSON.generate(canonical_payload))
  end

  private

  def canonical_payload
    {
      "schema_version" => @schema_version,
      "locale" => @locale,
      "title" => @title,
      "summary" => @summary,
      "body" => canonicalize(@body),
    }
  end

  def canonicalize(value)
    case value
    when Hash
      keys = value.keys.map(&:to_s)
      keys.sort!
      keys.index_with { |key|
        if value.key?(key)
          canonicalize(value[key])
        else
          canonicalize(value[key.to_sym])
        end
      }
    when Array
      value.map { |item| canonicalize(item) }
    else
      value
    end
  end
end
