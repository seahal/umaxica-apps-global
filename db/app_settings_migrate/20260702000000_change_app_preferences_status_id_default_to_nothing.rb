# typed: false
# frozen_string_literal: true

# app_preferences.status_id defaulted to AppPreferenceStatus::LEGACY_NOTHING (2),
# a backward-compat alias kept only for rows created before NOTHING (0) existed.
# New rows should get NOTHING like com/org_preferences already get their own
# NOTHING value (2) as the column default. Align the column default with the
# model's Ruby-level `attribute :status_id, default: AppPreferenceStatus::NOTHING`.
class ChangeAppPreferencesStatusIdDefaultToNothing < ActiveRecord::Migration[8.2]
  def up
    change_column_default :app_preferences, :status_id, from: 2, to: 0
  end

  def down
    change_column_default :app_preferences, :status_id, from: 0, to: 2
  end
end
