# typed: false
# frozen_string_literal: true

class RenameColorthemeForeignKeysToTheme < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      execute "ALTER TABLE com_preference_themes RENAME CONSTRAINT fk_com_preference_colorthemes_on_option_id TO fk_com_preference_themes_on_option_id"
    end
  end
end
