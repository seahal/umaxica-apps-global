# typed: false
# frozen_string_literal: true

# Mirror-side counterpart to app_settings_migrate/20260530120000_add_explicit_fields_to_app_preferences.rb.
#
# ClientPreference (the principal-scoped mirror of AppPreference) had no way to
# distinguish a value the account owner explicitly chose from a value that was
# only ever auto-seeded at signup or copied in by a prior sign-in merge. Without
# this column, PreferenceAdoption#sync_preferences! could only compare whole-row
# `updated_at` timestamps, which lets an unrelated key change (or a freshly
# created default row) silently overwrite every other key on the losing side.
#
# Deliberately added WITHOUT a backfill default and WITHOUT a NOT NULL
# constraint: `add_column` alone leaves every pre-existing row's
# `explicit_fields` at SQL NULL, which PreferenceExplicitFields treats as
# "legacy / provenance unknown" -- distinct from `[]` ("known: nothing marked
# explicit yet", e.g. a freshly created principal row). Setting the column
# default only *after* the column exists means the NULL default never
# retroactively applies to rows that already existed at migration time, while
# every row created afterwards (new signups, this migration onward) gets `[]`
# from the DB default and is "known" from creation. Backfilling every existing
# row to `[]` here would silently claim "we know these were never explicitly
# chosen," which is not true; backfilling to a fabricated explicit list would
# invent user intent that was never recorded. NULL is the only value that does
# not lie about either.
class AddExplicitFieldsToClientPreferences < ActiveRecord::Migration[8.2]
  def up
    add_column(:client_preferences, :explicit_fields, :jsonb)
    change_column_default(:client_preferences, :explicit_fields, [])
  end

  def down
    remove_column(:client_preferences, :explicit_fields)
  end
end
