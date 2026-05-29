# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "jwt"
require "openssl"
require "jit/security/jwt/registry"

module Preference
  # Resolves keysets, issuer, leeway and audience scoping for preference JWTs.
  # PREFERENCE_JWT_AUDIENCES is required; an empty or missing value causes
  # decoding to fail loudly rather than silently accepting any audience.
  module JwtConfiguration
    class MissingAudienceError < StandardError; end

    def self.active_kid
      Jit::Security::Jwt::Registry.preference.current_kid ||
        raise(Jit::Security::Jwt::Registry::ConfigurationError, "PREFERENCE_JWT_ACTIVE_KID is not configured")
    end

    def self.leeway_seconds
      Integer(ENV.fetch("PREFERENCE_JWT_LEEWAY_SECONDS", "30").to_s, 10)
    end

    def self.issuer
      ENV.fetch("PREFERENCE_JWT_ISSUER", "jit-preference")
    end

    def self.audiences
      raw = ENV["PREFERENCE_JWT_AUDIENCES"].to_s
      list = raw.split(",").map(&:strip).reject(&:empty?)
      raise MissingAudienceError, "PREFERENCE_JWT_AUDIENCES must be configured" if list.empty?

      list
    end

    # Returns the audiences that may legitimately accept a token issued for
    # the given host. Selects entries sharing the host's TLD so a .app token
    # cannot validate against the .com surface. In non-production the
    # configured "localhost"/"*.localhost" entry is always retained so local
    # development can move across surfaces.
    def self.audience_for(host)
      raise ArgumentError, "host is required" if host.blank?

      all = audiences
      host_tld = host.split(".").last
      matched = all.select { |aud| aud.split(".").last == host_tld }

      unless Rails.env.production?
        localhost_aud = all.find { |aud| aud == "localhost" || aud.end_with?(".localhost") }
        matched << localhost_aud if localhost_aud && matched.exclude?(localhost_aud)
      end

      raise MissingAudienceError, "No audience configured for host #{host.inspect}" if matched.empty?

      matched
    end

    def self.host_scope_for(host)
      raise ArgumentError, "host is required" if host.blank?

      matching_audience =
        audience_for(host).sort_by { |aud| -aud.to_s.length }.find do |aud|
          host == aud || host.end_with?(".#{aud}")
        end

      matching_audience || host
    end

    def self.private_key_for_active
      private_key_for(active_kid)
    end

    def self.private_key_for(kid)
      Jit::Security::Jwt::Registry.private_key_for("preference", kid)
    end

    def self.public_key_for(kid)
      Jit::Security::Jwt::Registry.public_key_for("preference", kid)
    end

    def self.private_key
      private_key_for(active_kid)
    end

    def self.public_key
      public_key_for(active_kid)
    end

    def self.parse_header(token)
      Jit::Security::Jwt::Registry.parse_header(token)
    end

    def self.parse_keyset(raw)
      return {} if raw.blank?

      parsed = JSON.parse(raw)
      return parsed if parsed.is_a?(Hash)

      {}
    rescue JSON::ParserError
      {}
    end

    def self.decode_key(base64_der)
      return nil if base64_der.blank?

      OpenSSL::PKey::EC.new(Base64.decode64(base64_der))
    rescue OpenSSL::PKey::PKeyError
      nil
    end
    private_class_method :parse_keyset, :decode_key
  end
end
