# typed: false
# frozen_string_literal: true

# WebAuthn Configuration
#
# This initializer sets up WebAuthn for Passkey authentication.
#
# IMPORTANT: TRUSTED_ORIGINS must be configured in environment variables.
# The application will fail to start if TRUSTED_ORIGINS is not set or empty.
#
# Environment Variables:
# - TRUSTED_ORIGINS: Comma-separated list of allowed origins (required)
#   - Development: http://id.app.localhost:3000,http://id.org.localhost:3000
#   - Production: https://id.app.example.com,https://id.org.example.com
# - WEBAUTHN_APP_RP_ID / WEBAUTHN_COM_RP_ID / WEBAUTHN_ORG_RP_ID: Public RP IDs.
# - WEBAUTHN_APP_ORIGIN / WEBAUTHN_COM_ORIGIN / WEBAUTHN_ORG_ORIGIN: Public origins.
# - WEBAUTHN_RP_ID / WEBAUTHN_ORIGIN: Shared fallback values.
#
# Note: rp_id is NOT configured on the global gem object. It is dynamically
# determined per-request in SignWebauthn, with environment overrides for
# deployments where Rails sees an internal host behind a proxy.

module Webauthn
  class TrustedOriginsNotConfiguredError < StandardError; end

  class << self
    def trusted_origins
      TRUSTED_ORIGINS
    end

    def validate_origin!(origin)
      return true if trusted_origins.include?(origin)

      raise WebAuthn::OriginVerificationError,
            "Origin '#{origin}' is not in TRUSTED_ORIGINS. " \
            "Allowed origins: #{trusted_origins.join(", ")}"
    end

    private

    def parse_trusted_origins
      origins = []
      origins.concat(ENV["TRUSTED_ORIGINS"].to_s.strip.split(","))
      origins.concat(
        [
          ENV["WEBAUTHN_APP_ORIGIN"],
          ENV["WEBAUTHN_COM_ORIGIN"],
          ENV["WEBAUTHN_ORG_ORIGIN"],
          ENV["WEBAUTHN_ORIGIN"],
        ],
      )
      origins.compact!
      origins.map! { |origin| origin.to_s.strip }
      origins.reject!(&:empty?)
      origins.uniq!

      if origins.empty?
        raise TrustedOriginsNotConfiguredError,
              "TRUSTED_ORIGINS environment variable is required but not set. " \
              "Please configure it with comma-separated origin URLs. " \
              "Example for development: TRUSTED_ORIGINS=http://id.app.localhost:3000, " \
              "http://id.org.localhost:3000. " \
              "Example for production: TRUSTED_ORIGINS=https://id.app.example.com, " \
              "https://id.org.example.com"
      end

      origins.each do |origin|
        uri = parse_origin_uri(origin)

        if Rails.env.production? && uri.scheme != "https"
          raise TrustedOriginsNotConfiguredError,
                "Production requires HTTPS origins. Found HTTP origin: '#{origin}'"
        end
      end

      origins.freeze
    end

    def parse_origin_uri(origin)
      uri = URI.parse(origin)
      return uri if uri.scheme && uri.host

      raise URI::InvalidURIError
    rescue URI::InvalidURIError
      raise TrustedOriginsNotConfiguredError,
            "Invalid origin format in TRUSTED_ORIGINS: '#{origin}'. " \
            "Origins must include scheme and host (e.g., https://example.com)"
    end
  end

  TRUSTED_ORIGINS = parse_trusted_origins
end

# Fail-fast: Validate TRUSTED_ORIGINS at application startup
Webauthn.trusted_origins

# Configure webauthn gem defaults
WebAuthn.configure do |config|
  # RP name for display in authenticator UI
  config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "Umaxica")

  # IMPORTANT: allowed_origins and rp_id are NOT set here.
  # They are dynamically configured per-request in SignWebauthn.
  # This allows:
  # - rp_id to vary by host (id.app.localhost vs id.org.localhost)
  # - origin validation to use our stricter Webauthn.validate_origin!

  # Use Base64URL encoding (default, but explicit for clarity)
  config.encoding = :base64url

  # Credential options timeout (2 minutes)
  config.credential_options_timeout = 120_000
end
