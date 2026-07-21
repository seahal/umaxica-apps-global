# typed: false
# frozen_string_literal: true

# Mirror-side counterpart to org_settings_migrate/20260530120000_add_explicit_fields_to_org_preferences.rb.
# See AddExplicitFieldsToClientPreferences for the full rationale (NULL means
# "legacy / provenance unknown", distinct from `[]`); this is the
# OrgPreference/OperatorPreference equivalent.
class AddExplicitFieldsToOperatorPreferences < ActiveRecord::Migration[8.2]
  def up
    add_column(:operator_preferences, :explicit_fields, :jsonb)
    change_column_default(:operator_preferences, :explicit_fields, [])
  end

  def down
    remove_column(:operator_preferences, :explicit_fields)
  end
end
