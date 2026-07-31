# typed: false
# frozen_string_literal: true

require "base64"
require "jwt"
require "openssl"
require "securerandom"

module ExternalAuthentication
  class EntraClientAssertionAdapter
    class ConfigurationError < StandardError; end

    ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
    LIFETIME = 5.minutes

    def initialize(connection:, token_url:, clock: -> { Time.current })
      @connection = connection
      @token_url = token_url
      @clock = clock
    end

    def call
      credential = Rails.app.creds.option(connection.entra_credential_key.to_sym)
      unless credential.is_a?(Hash)
        raise ConfigurationError, "Entra certificate credential is unavailable"
      end

      private_key = OpenSSL::PKey.read(credential.fetch(:private_key_pem))
      certificate = OpenSSL::X509::Certificate.new(credential.fetch(:certificate_pem))
      now = @clock.call.to_i
      payload = {
        aud: token_url,
        iss: connection.entra_client_id,
        sub: connection.entra_client_id,
        jti: SecureRandom.uuid,
        nbf: now,
        iat: now,
        exp: now + LIFETIME.to_i,
      }
      headers = {
        typ: "JWT",
        "x5t#S256": Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(certificate.to_der), padding: false),
      }
      JWT.encode(payload, private_key, "PS256", headers)
    rescue KeyError, ArgumentError, TypeError, OpenSSL::PKey::PKeyError, OpenSSL::X509::CertificateError => e
      raise ConfigurationError.new("Entra certificate credential is invalid"), cause: e
    end

    private

    attr_reader :connection, :token_url
  end
end
