# typed: false
# frozen_string_literal: true

class TrustedForwardedHeaders
  FORWARDED_HEADER_KEYS = %w(
    HTTP_FORWARDED
    HTTP_X_FORWARDED_FOR
    HTTP_X_FORWARDED_HOST
    HTTP_X_FORWARDED_PORT
    HTTP_X_FORWARDED_PROTO
    HTTP_CF_CONNECTING_IP
  ).freeze

  def initialize(app, trusted_proxies:)
    @app = app
    @trusted_proxies = trusted_proxies
  end

  def call(env)
    strip_forwarded_headers(env) unless trusted_peer?(env["REMOTE_ADDR"])
    app.call(env)
  end

  private

  attr_reader :app, :trusted_proxies

  def trusted_peer?(remote_address)
    address = IPAddr.new(remote_address.to_s)
    trusted_proxies.any? { |proxy| proxy.include?(address) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def strip_forwarded_headers(env)
    FORWARDED_HEADER_KEYS.each { |key| env.delete(key) }
  end
end
