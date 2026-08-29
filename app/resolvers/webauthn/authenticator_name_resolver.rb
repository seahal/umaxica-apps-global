# typed: false
# frozen_string_literal: true

module Webauthn
  # Resolves an AAGUID to a display-only friendly name via the local catalog
  # (config/webauthn/aaguid_catalog.yml). Returns nil for blank, zeroed, or
  # uncatalogued AAGUIDs - resolution failure must never fail a ceremony, and
  # the resolved name must never feed security decisions.
  #
  # The Result#source field exists so a future FIDO Metadata Service backend
  # can be added behind the same interface without a schema change
  # (metadata_source column on the passkey records).
  class AuthenticatorNameResolver
    CATALOG_PATH = Rails.root.join("config/webauthn/aaguid_catalog.yml")
    SOURCE_LOCAL_CATALOG = "local_catalog"

    Result = Data.define(:name, :source)

    CATALOG = YAML.safe_load_file(CATALOG_PATH).fetch("aaguids").transform_keys(&:downcase).freeze

    def self.resolve(aaguid)
      return nil if aaguid.blank?

      name = CATALOG[aaguid.to_s.downcase]
      return nil if name.nil?

      Result.new(name: name, source: SOURCE_LOCAL_CATALOG)
    end

    def self.catalog = CATALOG
  end
end
