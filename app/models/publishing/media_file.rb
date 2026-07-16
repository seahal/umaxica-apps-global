# typed: false
# frozen_string_literal: true

module Publishing
  class MediaFile < PublishingRecord
    self.table_name = "publishing_media_files"

    include PublicId

    has_many :media_usages, class_name: "Publishing::MediaUsage", inverse_of: :media_file, dependent: :restrict_with_exception
  end
end
