# typed: false
# frozen_string_literal: true

require "net/http"

class EntraJwksCache
  class FetchError < StandardError; end

  JWKS_URI_TEMPLATE = "https://login.microsoftonline.com/%s/discovery/v2.0/keys"
  CACHE_TTL = 1.hour

  def initialize(tenant_id:)
    @tenant_id = tenant_id
  end

  def call(options)
    Rails.cache.delete(cache_key) if options[:kid_not_found] || options[:invalidate]
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_jwks }
  end

  private

  attr_reader :tenant_id

  def cache_key
    "entra_sign_in/jwks/#{tenant_id}"
  end

  def fetch_jwks
    response = Net::HTTP.get_response(URI(format(JWKS_URI_TEMPLATE, tenant_id)))
    raise FetchError, "Entra JWKS request was not successful" unless response.is_a?(Net::HTTPSuccess)

    jwks = JSON.parse(response.body)
    raise FetchError, "Entra JWKS response has an invalid shape" unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array)

    jwks
  rescue JSON::ParserError, URI::InvalidURIError, Timeout::Error, SocketError, SystemCallError, TypeError => e
    raise FetchError, "Entra JWKS request failed", cause: e
  end
end
