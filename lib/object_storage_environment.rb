# frozen_string_literal: true

module ObjectStorage
  # Reads object-storage configuration from the process environment.
  #
  # Credentials are delivered as mounted Podman secrets, so their values are read
  # from a file path rather than from the variable itself. This mirrors
  # POSTGRESQL_PASSWORD_FILE in config/database.yml; the direct variables remain
  # supported for deployments whose credential provider exports values inline.
  module Environment
    module_function

    FILE_BACKED = %w(
      OBJECT_STORAGE_ACCESS_KEY_ID
      OBJECT_STORAGE_SECRET_ACCESS_KEY
    ).freeze

    # A configured `<NAME>_FILE` is authoritative: a missing or unreadable file
    # raises instead of falling back to the direct variable, so a broken secret
    # mount cannot quietly authenticate with stale or absent credentials.
    def fetch(name)
      path = ENV["#{name}_FILE"] if FILE_BACKED.include?(name)
      value = path.blank? ? ENV.fetch(name) : File.read(path).strip
      raise ArgumentError, "#{name} must not be blank" if value.empty?

      value
    end

    def fetch_boolean(name)
      value = fetch(name)
      return true if value == "true"
      return false if value == "false"

      raise ArgumentError, "#{name} must be exactly true or false"
    end

    # Whether the caller has opted into the configuration described by `names`.
    #
    # None set means "not opted in" and returns false. All set means "opted in"
    # and returns true. A partial set raises: it always means a typo, a missing
    # secret mount, or a half-finished setup, and silently selecting a different
    # storage would hide that.
    #
    # This is an opt-in predicate, not a required-configuration read, so it
    # inspects ENV directly. It is never consulted on the production path, where a
    # missing value must fail rather than select a different storage.
    def configured?(names)
      present, missing = names.partition { |name| present?(name) }
      return false if present.empty?
      return true if missing.empty?

      raise ArgumentError,
            "incomplete object-storage configuration: #{present.join(", ")} set but " \
            "#{missing.join(", ")} missing; set all of them or none"
    end

    def present?(name)
      path = ENV["#{name}_FILE"] if FILE_BACKED.include?(name)
      return !ENV[name].to_s.empty? if path.blank?

      File.exist?(path) && !File.read(path).strip.empty?
    end
  end
end

# Zeitwerk expects the flat constant matching the file name; the nested constant
# above is the one application code uses.
ObjectStorageEnvironment = ObjectStorage::Environment
