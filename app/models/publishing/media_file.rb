# frozen_string_literal: true

module Publishing
  class MediaFile < PublishingRecord
    self.table_name = "publishing_media_files"

    include PublicId
  end
end
