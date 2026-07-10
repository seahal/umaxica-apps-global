# typed: false
# frozen_string_literal: true

require "net/http"

module ExternalSignIn
  # Fetches and caches the Entra ID JWKS for a specific tenant.
  # Returns a callable suitable for the JWT gem's jwks: option.
  # Cache is invalidated when the JWT gem signals kid_not_found (key rotation).
  class EntraJwksCache
    JWKS_URI_TEMPLATE = "https://login.microsoftonline.com/%s/discovery/v2.0/keys"
    CACHE_TTL = 1.hour

    def initialize(tenant_id:)
      @tenant_id = tenant_id
    end

    # Returns a proc compatible with JWT.decode's jwks: option.
    # Receives {kid_not_found: true} from the JWT gem when the signing key is absent
    # from the cached set; responds by invalidating and re-fetching once.
    def loader
      ->(options) {
        Rails.cache.delete(cache_key) if options[:kid_not_found] || options[:invalidate]
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_jwks }
      }
    end

    private

    attr_reader :tenant_id

    def cache_key
      "external_sign_in/entra_jwks/#{tenant_id}"
    end

    def fetch_jwks
      uri = URI(format(JWKS_URI_TEMPLATE, tenant_id))
      response = Net::HTTP.get_response(uri)
      raise StandardError, "JWKS fetch failed (HTTP #{response.code}) for tenant #{tenant_id}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
