# typed: false
# frozen_string_literal: true

require "shrine"
require "shrine/storage/file_system"
require "shrine/storage/memory"

Shrine.storages =
  if Rails.env.test?
    {
      cache: Shrine::Storage::Memory.new,
      store: Shrine::Storage::Memory.new,
    }
  else
    {
      cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
      store: Shrine::Storage::FileSystem.new("public", prefix: "uploads"),
    }
  end

Shrine.plugin(:activerecord)
Shrine.plugin(:cached_attachment_data)
Shrine.plugin(:restore_cached_data)
