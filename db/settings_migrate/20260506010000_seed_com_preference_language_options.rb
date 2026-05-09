# frozen_string_literal: true

class SeedComPreferenceLanguageOptions < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:com_preference_language_options)

    safety_assured do
      [1, 2].each do |id|
        execute(<<~SQL.squish)
          INSERT INTO com_preference_language_options (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def down
    # Keep shared reference data in place once introduced.
  end
end
