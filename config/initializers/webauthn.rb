# typed: false
# frozen_string_literal: true

# WebAuthn Configuration
#
# This initializer sets up WebAuthn for Passkey authentication.
#
# IMPORTANT: WebAuthn trusted origins are derived from public Auth hosts.
# The application will fail to start if no public Auth host or explicit origin is configured.
#
# Environment Variables:
# - PUBLIC_AUTH_SERVICE_URL / PUBLIC_AUTH_CORPORATE_URL / PUBLIC_AUTH_STAFF_URL:
#   Public browser hosts for the Auth surfaces (required unless explicit WebAuthn origins are set).
# - TRUSTED_ORIGINS: Optional comma-separated additional origins.
# - WEBAUTHN_APP_RP_ID / WEBAUTHN_COM_RP_ID / WEBAUTHN_ORG_RP_ID: Public RP IDs.
# - WEBAUTHN_APP_ORIGIN / WEBAUTHN_COM_ORIGIN / WEBAUTHN_ORG_ORIGIN: Public origins.
# - WEBAUTHN_RP_ID / WEBAUTHN_ORIGIN: Shared fallback values.
#
# Note: rp_id is NOT configured on the global gem object. It is dynamically
# determined per-request in SignWebauthn, with environment overrides for
# deployments where Rails sees an internal host behind a proxy.

require "jit_host_origin_env"

module Webauthn
  class TrustedOriginsNotConfiguredError < StandardError; end

  # Raised at startup when production is missing RP_ID env vars.
  # Without an explicit RP_ID, rpId falls back to request.host, which is
  # attacker-controllable via Host header injection and enables rpId confusion.
  class MissingRpIdError < StandardError; end

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

    # Raises MissingRpIdError in production when no surface has an RP_ID configured.
    # Each WebAuthn surface (APP/COM/ORG) must have either WEBAUTHN_<SURFACE>_RP_ID
    # or the shared WEBAUTHN_RP_ID set. Checked at startup before the first request.
    def validate_rp_id_configuration!
      return unless Rails.env.production?

      shared_rp_id = ENV["WEBAUTHN_RP_ID"].to_s.strip

      %w(APP COM ORG).each do |surface|
        next if ENV["WEBAUTHN_#{surface}_RP_ID"].to_s.strip.present?
        next if shared_rp_id.present?

        raise MissingRpIdError,
              "WEBAUTHN_#{surface}_RP_ID or WEBAUTHN_RP_ID must be set in production. " \
              "Without it, webauthn_rp_id falls back to request.host, which is " \
              "attacker-controllable via Host header injection."
      end
    end

    private

    def parse_trusted_origins
      origins = JitHostOriginEnv.trusted_origins(
        ENV["PUBLIC_AUTH_SERVICE_URL"],
        ENV["PUBLIC_AUTH_CORPORATE_URL"],
        ENV["PUBLIC_AUTH_STAFF_URL"],
        ENV["WEBAUTHN_APP_ORIGIN"],
        ENV["WEBAUTHN_COM_ORIGIN"],
        ENV["WEBAUTHN_ORG_ORIGIN"],
        ENV["WEBAUTHN_ORIGIN"],
        ENV["TRUSTED_ORIGINS"].to_s.split(","),
      )

      if origins.empty?
        raise TrustedOriginsNotConfiguredError,
              "WebAuthn trusted origins are not configured. " \
              "Configure PUBLIC_AUTH_SERVICE_URL, PUBLIC_AUTH_CORPORATE_URL, " \
              "and PUBLIC_AUTH_STAFF_URL with public Auth hosts. " \
              "TRUSTED_ORIGINS may be set only for additional explicit origins."
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

# Fail-fast: Validate WebAuthn trusted origins at application startup
Webauthn.trusted_origins

# Fail-fast: Validate RP_ID configuration at application startup
Webauthn.validate_rp_id_configuration!

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
