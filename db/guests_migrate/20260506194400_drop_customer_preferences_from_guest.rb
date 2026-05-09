# frozen_string_literal: true

# NOTE: This migration should ONLY be run AFTER:
#   1. All customer_preferences data has been migrated to setting DB
#   2. Application code has been updated to use SettingRecord
#   3. The application has been verified to work correctly with the new DB
#
# This is a POST-CUTOVER migration to clean up old tables from guest DB.

class DropCustomerPreferencesFromGuest < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      drop_table :customer_preference_languages
      drop_table :customer_preference_timezones
      drop_table :customer_preference_regions
      drop_table :customer_preference_colorthemes
      drop_table :customer_preference_language_options
      drop_table :customer_preference_timezone_options
      drop_table :customer_preference_region_options
      drop_table :customer_preference_colortheme_options
      drop_table :customer_preferences
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
