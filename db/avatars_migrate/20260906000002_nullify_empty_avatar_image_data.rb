# frozen_string_literal: true

class NullifyEmptyAvatarImageData < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE avatars
        SET image_data = NULL
        WHERE image_data = '{}'::jsonb
      SQL
    end
  end

  def down
    safety_assured do
      execute <<~SQL.squish
        UPDATE avatars
        SET image_data = '{}'::jsonb
        WHERE image_data IS NULL
      SQL
    end
  end
end
