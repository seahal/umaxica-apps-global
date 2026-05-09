# typed: false
# frozen_string_literal: true

class RenameColorthemeTablesToTheme < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      rename_table :com_preference_colorthemes, :com_preference_themes
      rename_table :com_preference_colortheme_options, :com_preference_theme_options
      rename_table :customer_preference_colorthemes, :customer_preference_themes
      rename_table :customer_preference_colortheme_options, :customer_preference_theme_options
    end
  end
end
