# frozen_string_literal: true

class AddFileDataToPublishingMediaFiles < ActiveRecord::Migration[8.2]
  def change
    add_column :publishing_media_files, :file_data, :jsonb
  end
end
