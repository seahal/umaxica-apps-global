# typed: false
# frozen_string_literal: true

class RenameColorthemeTablesToTheme < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      rename_table :app_preference_colorthemes, :app_preference_themes
      rename_table :app_preference_colortheme_options, :app_preference_theme_options
      rename_table :user_preference_colorthemes, :user_preference_themes
      rename_table :user_preference_colortheme_options, :user_preference_theme_options
    end
  end
end
