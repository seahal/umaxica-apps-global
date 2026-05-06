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
#
# Note: rp_id is NOT configured here. It is dynamically determined per-request
# using request.host in the Webauthn::Config concern. This allows different
# rp_id values for service (id.app.localhost) and staff (id.org.localhost).

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
      raw = ENV["TRUSTED_ORIGINS"].to_s.strip
      origins = raw.split(",")
      origins.map!(&:strip)
      origins.reject!(&:empty?)

      if origins.empty?
        raise TrustedOriginsNotConfiguredError,
              "TRUSTED_ORIGINS environment variable is required but not set. " \
              "Please configure it with comma-separated origin URLs. " \
              "Example for development: TRUSTED_ORIGINS=http://id.app.localhost:3000, " \
              "http://id.org.localhost:3000" \
              "Example for production: TRUSTED_ORIGINS=https://id.app.example.com, " \
              "https://id.org.example.com"
      end

      # Validate origin format
      origins.each do |origin|
        uri = URI.parse(origin)
        unless uri.scheme && uri.host
          raise TrustedOriginsNotConfiguredError,
                "Invalid origin format in TRUSTED_ORIGINS: '#{origin}'. " \
                "Origins must include scheme and host (e.g., https://example.com)"
        end

        # Production must use HTTPS
        if Rails.env.production? && uri.scheme != "https"
          raise TrustedOriginsNotConfiguredError,
                "Production requires HTTPS origins. Found HTTP origin: '#{origin}'"
        end
      end

      origins.freeze
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
  # They are dynamically configured per-request in Webauthn::Config concern.
  # This allows:
  # - rp_id to vary by host (id.app.localhost vs id.org.localhost)
  # - origin validation to use our stricter Webauthn.validate_origin!

  # Use Base64URL encoding (default, but explicit for clarity)
  config.encoding = :base64url

  # Credential options timeout (2 minutes)
  config.credential_options_timeout = 120_000
end
