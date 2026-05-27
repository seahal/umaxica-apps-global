# typed: false
# frozen_string_literal: true

require "jwt"

module JumpRt
  class Issuer
    ALGORITHM = "ES384"
    AUDIENCE_ENV = "JUMP_GATEWAY_URL"
    DEFAULT_AUDIENCE = "https://jump.umaxica.net"
    DEFAULT_TTL = 15.minutes
    MAX_TTL = 30.days
    TOKEN_SUBJECT = "jump-redirect"
    VALID_DESTINATIONS = %w(internal external).freeze

    def self.call(...)
      new(...).call
    end

    def initialize(namespace:, url:, dst: "internal", ttl: DEFAULT_TTL, now: Time.current, jti: SecureRandom.uuid)
      @namespace = JumpRt::Surface.normalize_namespace(namespace)
      @url = url
      @dst = dst.to_s
      @ttl = ttl
      @now = now
      @jti = jti
    end

    def call
      return nil unless valid_destination?
      return nil unless valid_ttl?

      normalized_url = normalize_url(url)
      return nil if normalized_url.blank?

      kid = JumpRt::Keyring.active_kid(namespace)
      private_key = JumpRt::Keyring.private_key(namespace)
      return nil if kid.blank? || private_key.blank?

      JWT.encode(
        payload(normalized_url),
        private_key,
        ALGORITHM,
        { typ: "JWT", kid: kid },
      )
    end

    private

    attr_reader :namespace, :url, :dst, :ttl, :now, :jti

    def payload(normalized_url)
      issued_at = now.to_i
      {
        schema: 1,
        iss: JumpRt::Surface.issuer_origin(namespace),
        aud: jump_audience,
        sub: TOKEN_SUBJECT,
        iat: issued_at,
        nbf: issued_at,
        exp: issued_at + ttl.to_i,
        jti: jti,
        dst: dst,
        url: normalized_url,
      }
    end

    def normalize_url(value)
      raw = value.to_s
      return nil if raw.blank?
      return nil if raw.match?(/[\x00-\x1F\x7F]/)

      uri = URI.parse(raw)
      return nil unless uri.is_a?(URI::HTTP)
      return nil unless uri.scheme == "https" || local_http_allowed?(uri)
      return nil if uri.host.blank?
      return nil if uri.userinfo.present?
      return nil if uri.fragment.present?

      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.path = "/" if uri.path.blank?
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end

    def valid_destination?
      VALID_DESTINATIONS.include?(dst)
    end

    def valid_ttl?
      ttl.to_i.positive? && ttl.to_i <= MAX_TTL.to_i
    end

    def jump_audience
      ENV.fetch(AUDIENCE_ENV, DEFAULT_AUDIENCE).presence || DEFAULT_AUDIENCE
    end

    def local_http_allowed?(uri)
      return false unless Rails.env.local?

      uri.scheme == "http" && (uri.host == "localhost" || uri.host.end_with?(".localhost"))
    end
  end
end
