# frozen_string_literal: true

class RemoveAppPreferenceLanguageOptionZero < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:app_preference_language_options)

    safety_assured do
      execute(<<~SQL.squish)
        UPDATE app_preference_languages
        SET option_id = 1
        WHERE option_id = 0
      SQL

      execute(<<~SQL.squish)
        DELETE FROM app_preference_language_options
        WHERE id = 0
      SQL
    end
  end

  def down
    return unless table_exists?(:app_preference_language_options)

    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO app_preference_language_options (id)
        VALUES (0)
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end
end
