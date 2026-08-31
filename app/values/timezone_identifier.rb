# typed: false
# frozen_string_literal: true

# Canonical IANA time zone name for a preference value.
#
# Every surface reads the same preference (query overlay, preference cookie,
# actor record, preference option row) but each entry point used to normalize it
# differently: some folded the lowercase `jst`/`utc` spellings, only one
# validated the result, and the rest let an arbitrary string reach `Time.zone=`.
# This is the single place that decides what a stored or submitted value means.
#
# `normalize` never guesses: an unknown name is nil, and the caller names the
# fallback it wants.
module TimezoneIdentifier
  # Matches Actor::Preference::DEFAULTS[:timezone] and the `timezone` column
  # default on every preference table.
  DEFAULT = "Asia/Tokyo"

  # The `tz` query parameter and the preference cookie carry downcased values,
  # while ActiveSupport::TimeZone[] only answers to the canonical mixed-case
  # identifier. Names are therefore matched case-insensitively, so a preference
  # set through the URL resolves to the same zone as one read from a record.
  # `jst` is the one spelling that is not an identifier or an ActiveSupport
  # name, so it is mapped explicitly.
  ALIASES = { "jst" => "Asia/Tokyo" }.freeze

  module_function

  # Canonical IANA name, or nil when the value is blank or not a real zone.
  def normalize(value)
    candidate = value.to_s.strip
    return nil if candidate.blank?

    identifier = canonical_identifier(candidate.downcase)
    return nil if identifier.nil?

    zone = ActiveSupport::TimeZone[identifier]
    return nil if zone.nil?

    zone.tzinfo&.name || zone.name
  end

  def valid?(value)
    normalize(value).present?
  end

  # First candidate that normalizes, else the caller's explicit default.
  def resolve(*candidates, default: DEFAULT)
    candidates.each do |candidate|
      normalized = normalize(candidate)
      return normalized if normalized.present?
    end

    default
  end

  # Downcased spelling -> canonical identifier, covering the IANA identifiers and
  # the friendly ActiveSupport names ("Tokyo") alike. Built once at load rather
  # than memoized per call: it is a property of the tz database, not of a
  # request, and a frozen constant needs no lock to be shared across threads.
  CANONICAL_IDENTIFIERS =
    ActiveSupport::TimeZone::MAPPING
      .transform_keys(&:downcase)
      .merge(TZInfo::Timezone.all_identifiers.index_by(&:downcase))
      .merge(ALIASES)
      .freeze

  def canonical_identifier(downcased)
    CANONICAL_IDENTIFIERS[downcased]
  end
end
