# typed: false
# frozen_string_literal: true

require "shrine"
require Rails.root.join("lib/object_storage_shrine_configuration").to_s

# Storage selection is delegated to ObjectStorage::ShrineConfiguration, which
# resolves an explicit mode per environment and has no FileSystem branch on the
# production path, so production cannot write attachments to the public web root.
Shrine.storages = ObjectStorage::ShrineConfiguration.storages

Shrine.plugin(:activerecord)
Shrine.plugin(:cached_attachment_data)
Shrine.plugin(:restore_cached_data)

# MIME type is determined from file content rather than from the client-supplied
# value, so validate_mime_type in an uploader is trustworthy.
Shrine.plugin(:determine_mime_type, analyzer: :marcel)
Shrine.plugin(:validation_helpers)
Shrine.plugin(:default_storage)

# Per-boundary storages are resolved lazily by name, e.g. :avatar_store. A
# resolver returning nil makes Shrine.find_storage raise Shrine::MissingStorage,
# so an unregistered boundary fails closed instead of falling back to a shared
# namespace.
Shrine.plugin(:dynamic_storage)
Shrine.storage(/\A(?<boundary>[a-z_]+)_(?<role>cache|store)\z/) do |match|
  ObjectStorage::ShrineConfiguration.dynamic(match[:boundary], match[:role])
end

# Boundary storages are otherwise resolved lazily, which would defer a missing
# bucket or region to the first upload. Resolving every registered boundary now
# moves that failure to boot. No boundary is registered yet, so this is currently
# a no-op; it starts validating as soon as one is.
ObjectStorage::ShrineConfiguration.verify_registered_boundaries!
