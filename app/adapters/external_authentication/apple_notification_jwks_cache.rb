# typed: false
# frozen_string_literal: true

require "json"

module ExternalAuthentication
  class AppleNotificationJwksCache
    class FetchError < StandardError; end

    JWKS_URI = URI("https://appleid.apple.com/auth/keys")
    CACHE_TTL = 1.hour
    MAXIMUM_RESPONSE_BYTES = 64.kilobytes
    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 5

    def initialize(fetcher: nil)
      @fetcher = fetcher || method(:fetch_jwks)
    end

    def loader
      lambda do |options|
        Rails.cache.delete(cache_key) if options[:kid_not_found] || options[:invalidate]
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetcher.call }
      end
    end

    private

    attr_reader :fetcher

    def cache_key
      "external_authentication/apple_notification_jwks"
    end

    def fetch_jwks
      connection = OutboundHttp::Connection.build(
        url: JWKS_URI,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        require_https: true,
      )
      response = connection.get(JWKS_URI)
      raise FetchError unless response.success?
      raise FetchError if response.body.to_s.bytesize > MAXIMUM_RESPONSE_BYTES

      jwks = JSON.parse(response.body)
      raise FetchError unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array)

      jwks
    rescue JSON::ParserError, TypeError, *OutboundHttp::Connection::NETWORK_ERRORS
      raise FetchError
    end
  end
end
