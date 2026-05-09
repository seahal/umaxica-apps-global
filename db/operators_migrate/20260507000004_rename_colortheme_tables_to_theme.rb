# typed: false
# frozen_string_literal: true

class RenameColorthemeTablesToTheme < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      rename_table :org_preference_colorthemes, :org_preference_themes
      rename_table :org_preference_colortheme_options, :org_preference_theme_options
      rename_table :staff_preference_colorthemes, :staff_preference_themes
      rename_table :staff_preference_colortheme_options, :staff_preference_theme_options
    end
  end
end
