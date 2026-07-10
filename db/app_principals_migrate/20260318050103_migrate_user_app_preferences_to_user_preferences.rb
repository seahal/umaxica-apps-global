# frozen_string_literal: true

class MigrateUserAppPreferencesToUserPreferences < ActiveRecord::Migration[8.1]
  # This migration converts existing UserAppPreference/StaffOrgPreference join records
  # into the new 1:1 UserPreference/StaffPreference records.
  #
  # Since UserAppPreference is in the preference DB and UserPreference is in the principal DB,
  # this migration must be run AFTER creating the new tables (20260318050102).
  #
  # Run with: bin/rails db:migrate
  # The actual data migration logic is in a Rake task to allow re-running:
  #   bin/rails preference:migrate_to_user_staff

  def up
    # Data migration is handled by rake task: preference:migrate_to_user_staff
    # This migration is a no-op placeholder to record that the schema supports the new model.
    Rails.logger.info("[Migration] UserPreference/StaffPreference tables ready. Run `rake preference:migrate_to_user_staff` to migrate data.")
  end

  def down
    # No-op: data migration is not reversible via migration
  end
end
