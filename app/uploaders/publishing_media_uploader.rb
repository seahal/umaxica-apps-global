# frozen_string_literal: true

class PublishingMediaUploader < ApplicationUploader
  MAX_SIZE = 10 * 1024 * 1024
  ALLOWED_MIME_TYPES = %w(image/jpeg image/png image/webp image/gif).freeze

  def self.storage_boundary
    :publishing
  end

  Attacher.validate do
    validate_max_size MAX_SIZE
    validate_mime_type ALLOWED_MIME_TYPES
  end
end
