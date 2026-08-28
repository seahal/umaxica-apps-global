# typed: false
# frozen_string_literal: true

module ExternalSignIn
  # Fetches and caches the Entra ID JWKS for a specific tenant.
  # Returns a callable suitable for the JWT gem's jwks: option.
  # Cache is invalidated when the JWT gem signals kid_not_found (key rotation).
  class EntraJwksCache
    class FetchError < StandardError; end

    JWKS_URI_TEMPLATE = "https://login.microsoftonline.com/%s/discovery/v2.0/keys"
    CACHE_TTL = 1.hour
    # This fetch previously ran on the stdlib default read timeout, so an
    # unresponsive Entra endpoint held a sign-in request thread for a minute.
    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 5

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
      connection = OutboundHttp::Connection.build(
        url: uri,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        require_https: true,
      )
      response = connection.get(uri)
      raise FetchError, "JWKS fetch failed (HTTP #{response.status}) for tenant #{tenant_id}" unless response.success?

      jwks = JSON.parse(response.body)
      raise FetchError,
            "JWKS response has an invalid shape for tenant " \
            "#{tenant_id}" unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array)

      jwks
    rescue JSON::ParserError, URI::InvalidURIError, TypeError, *OutboundHttp::Connection::NETWORK_ERRORS => e
      raise FetchError.new("JWKS request failed for tenant #{tenant_id}"), cause: e
    end
  end
end
