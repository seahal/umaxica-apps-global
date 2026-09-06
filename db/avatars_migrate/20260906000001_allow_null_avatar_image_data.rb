# frozen_string_literal: true

# Shrine stores attachment metadata in image_data. An empty JSON object is not a
# valid Shrine payload (UploadedFile requires id and storage), and detaching an
# image writes NULL. The previous NOT NULL default of {} made both cases raise.
class AllowNullAvatarImageData < ActiveRecord::Migration[8.2]
  def change
    change_column_null :avatars, :image_data, true
    change_column_default :avatars, :image_data, from: {}, to: nil
  end
end
