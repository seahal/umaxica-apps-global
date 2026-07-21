# typed: false
# frozen_string_literal: true

# Mirror-side counterpart to com_settings_migrate/20260530120000_add_explicit_fields_to_com_preferences.rb.
# See AddExplicitFieldsToClientPreferences for the full rationale (NULL means
# "legacy / provenance unknown", distinct from `[]`); this is the
# ComPreference/VisitorPreference equivalent.
class AddExplicitFieldsToVisitorPreferences < ActiveRecord::Migration[8.2]
  def up
    add_column(:visitor_preferences, :explicit_fields, :jsonb)
    change_column_default(:visitor_preferences, :explicit_fields, [])
  end

  def down
    remove_column(:visitor_preferences, :explicit_fields)
  end
end
