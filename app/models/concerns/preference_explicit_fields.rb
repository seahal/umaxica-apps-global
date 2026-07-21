# typed: false
# frozen_string_literal: true

# Tracks which preference fields the user set explicitly.
#
# Child preference records (language, region, ...) are always created with a
# default option on first visit, so a child's presence or value cannot tell
# an explicit choice apart from an auto-seeded default. The `explicit_fields`
# jsonb column records the field names the user changed on purpose. This drives
# localization: an explicitly set language wins over dynamic region seeding
# (?ri), while an unset (default-only) field stays eligible for seeding.
#
# Three distinct states, not two:
#   - SQL NULL         -- "legacy / provenance unknown". Only possible on rows
#                          that existed before `explicit_fields` was added to
#                          this model's table (see
#                          db/app_zenith_migrate/20260721090000_...rb and its
#                          org/com siblings). A row in this state predates the
#                          column entirely, so its history genuinely cannot be
#                          known -- it must not be treated the same as "known:
#                          nothing chosen yet", because a per-key reconciler
#                          that treats it that way would let an unrelated
#                          browser's explicit marker silently overwrite an
#                          established value the account owner set years ago
#                          under the old whole-record merge.
#   - `[]`              -- "known: nothing marked explicit yet" (a freshly
#                          created row, or a row explicitly reset).
#   - `["language", ...]` -- "known: these fields were explicitly chosen."
# The column has no NOT NULL constraint and no backfill: existing rows keep
# their legacy NULL forever unless an explicit user action on that specific
# row transitions it (see `mark_field_explicit!`), which is a deliberate
# choice to never fabricate historical intent that was never recorded.
module PreferenceExplicitFields
  extend ActiveSupport::Concern

  def explicit_field?(field)
    explicit_field_names.include?(field.to_s)
  end

  def explicit_field_names
    Array(explicit_fields).map(&:to_s)
  end

  # True only for a row that predates the `explicit_fields` column and has
  # never had a field explicitly marked since. Callers merging browser and
  # principal state must treat this as neither "explicit" nor "known
  # non-explicit" -- see PreferenceAdoption#reconcile_preference_key!.
  def legacy_unknown_explicit_state?
    explicit_fields.nil?
  end

  def mark_field_explicit!(field)
    normalized = field.to_s
    names = explicit_field_names
    return if names.include?(normalized)

    update!(explicit_fields: (names + [normalized]).uniq)
  end

  def clear_explicit_fields!
    return if explicit_field_names.empty? && !legacy_unknown_explicit_state?

    update!(explicit_fields: [])
  end
end
