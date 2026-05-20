# typed: false
# frozen_string_literal: true

class RenameColorthemeForeignKeysToTheme < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      execute "ALTER TABLE user_preference_themes RENAME CONSTRAINT fk_user_preference_colorthemes_on_option_id TO fk_user_preference_themes_on_option_id"
      execute "ALTER TABLE user_preference_themes RENAME CONSTRAINT fk_user_preference_colorthemes_on_preference_id TO fk_user_preference_themes_on_preference_id"
    end
  end
end
