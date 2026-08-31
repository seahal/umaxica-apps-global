# frozen_string_literal: true

require_relative "object_storage_environment"

module ObjectStorage
  # Maps a storage boundary to its object-storage bucket.
  #
  # A storage boundary is deliberately a third concept, separate from both the
  # database connection name and any future public URL namespace:
  #
  #   database connection name  ->  :avatar, :publishing, ...
  #   storage boundary key      ->  what this registry names
  #   public URL namespace      ->  undecided; not represented here
  #
  # Keeping them separate means a database rename or consolidation does not
  # rewrite object keys, and the physical database name never becomes part of a
  # delivery contract. Bucket identity is likewise not derived from the database
  # name; it is read from an explicitly named variable per boundary.
  #
  # REGISTRY is intentionally empty. A boundary is registered only when a model in
  # that boundary actually declares an attachment, so boundaries without
  # attachments (cache, queue, search, occurrence, chronicle, ticket, setting,
  # signal) impose no bucket requirement on any deployment.
  module Boundary
    module_function

    REGISTRY = {}.freeze

    def keys
      REGISTRY.keys
    end

    def registered?(boundary)
      REGISTRY.key?(boundary.to_sym)
    end

    def bucket_variable(boundary)
      suffix =
        REGISTRY.fetch(boundary.to_sym) do
          raise ArgumentError, "unregistered object-storage boundary: #{boundary.inspect}"
        end

      "OBJECT_STORAGE_BUCKET_#{suffix}"
    end

    def bucket(boundary)
      Environment.fetch(bucket_variable(boundary))
    end
  end
end

# Zeitwerk expects the flat constant matching the file name.
ObjectStorageBoundary = ObjectStorage::Boundary
