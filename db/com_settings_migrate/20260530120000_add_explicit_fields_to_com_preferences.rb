# typed: false
# frozen_string_literal: true

# Adds the explicit-set marker for preference fields.
#
# Child preference records (language, region, ...) are always created with a
# default option on first visit, so their presence cannot distinguish a value
# the user explicitly chose from an auto-seeded default. `explicit_fields`
# records the field names the user set on purpose, which drives whether a saved
# value wins over dynamic region seeding (?ri) at localization time.
class AddExplicitFieldsToComPreferences < ActiveRecord::Migration[8.2]
  def change
    add_column :com_preferences, :explicit_fields, :jsonb, default: [], null: false
  end
end
