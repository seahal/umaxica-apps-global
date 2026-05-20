# frozen_string_literal: true

# NOTE: This migration should ONLY be run AFTER:
#   1. All staff_preferences data has been migrated to operator DB
#   2. Application code has been updated to use OrgPrincipalRecord
#   3. The application has been verified to work correctly with the new DB
#
# This is a POST-CUTOVER migration to clean up old tables from principal DB.

class DropStaffPreferencesFromPrincipal < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      # Drop child tables first (respecting FK dependencies)
      drop_table :staff_preference_languages, if_exists: true
      drop_table :staff_preference_timezones, if_exists: true
      drop_table :staff_preference_regions, if_exists: true
      drop_table :staff_preference_colorthemes, if_exists: true

      # Drop option tables
      drop_table :staff_preference_language_options, if_exists: true
      drop_table :staff_preference_timezone_options, if_exists: true
      drop_table :staff_preference_region_options, if_exists: true
      drop_table :staff_preference_colortheme_options, if_exists: true

      # Drop parent table last
      drop_table :staff_preferences, if_exists: true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
