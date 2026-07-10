# typed: false
# frozen_string_literal: true

class RenameColorthemeTablesToTheme < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      rename_table :staff_preference_colorthemes, :staff_preference_themes
      rename_table :staff_preference_colortheme_options, :staff_preference_theme_options
    end
  end
end
