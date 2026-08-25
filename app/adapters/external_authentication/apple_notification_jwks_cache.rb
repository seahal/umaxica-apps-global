# typed: false
# frozen_string_literal: true

require "json"
require "net/http"

module ExternalAuthentication
  class AppleNotificationJwksCache
    class FetchError < StandardError; end

    JWKS_URI = URI("https://appleid.apple.com/auth/keys")
    CACHE_TTL = 1.hour
    MAXIMUM_RESPONSE_BYTES = 64.kilobytes

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
      response =
        Net::HTTP.start(
          JWKS_URI.host,
          JWKS_URI.port,
          use_ssl: true,
          open_timeout: 2,
          read_timeout: 5,
        ) { |http| http.request(Net::HTTP::Get.new(JWKS_URI)) }
      raise FetchError unless response.is_a?(Net::HTTPSuccess)
      raise FetchError if response.body.to_s.bytesize > MAXIMUM_RESPONSE_BYTES

      jwks = JSON.parse(response.body)
      raise FetchError unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array)

      jwks
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, TypeError
      raise FetchError
    end
  end
end
