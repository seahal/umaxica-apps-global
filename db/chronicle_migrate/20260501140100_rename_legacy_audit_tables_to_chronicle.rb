# frozen_string_literal: true

class RenameLegacyAuditTablesToChronicle < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      # Activity Group
      rename_table :user_activities, :user_chronicles
      rename_table :user_activity_events, :user_chronicle_events
      rename_table :user_activity_levels, :user_chronicle_levels
      rename_table :staff_activities, :staff_chronicles
      rename_table :staff_activity_events, :staff_chronicle_events
      rename_table :staff_activity_levels, :staff_chronicle_levels

      # Preference Group
      rename_table :app_preference_activities, :app_preference_chronicles
      rename_table :app_preference_activity_events, :app_preference_chronicle_events
      rename_table :app_preference_activity_levels, :app_preference_chronicle_levels
      rename_table :com_preference_activities, :com_preference_chronicles
      rename_table :com_preference_activity_events, :com_preference_chronicle_events
      rename_table :com_preference_activity_levels, :com_preference_chronicle_levels
      rename_table :org_preference_activities, :org_preference_chronicles
      rename_table :org_preference_activity_events, :org_preference_chronicle_events
      rename_table :org_preference_activity_levels, :org_preference_chronicle_levels

      # Scavenger Group
      rename_table :scavenger_globals, :scavenger_global_chronicles
      rename_table :scavenger_global_events, :scavenger_global_chronicle_events
      rename_table :scavenger_global_statuses, :scavenger_global_chronicle_statuses
      rename_table :scavenger_regionals, :scavenger_regional_chronicles
      rename_table :scavenger_regional_events, :scavenger_regional_chronicle_events
      rename_table :scavenger_regional_statuses, :scavenger_regional_chronicle_statuses
    end
  end
end
