# typed: false
# frozen_string_literal: true

require "json"
require "securerandom"
require "active_support/security_utils"

module ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement
  ALLOWED_ISSUERS = ["accounts.google.com", "https://accounts.google.com"].freeze
  ALLOWED_ALGORITHMS = ["RS256"].freeze
  JWKS_URI = URI("https://www.googleapis.com/oauth2/v3/certs")
  JWKS_CACHE_KEY = "external_authentication/google_oidc/jwks"
  JWKS_CACHE_TTL = 1.hour
  JWKS_TIMEOUT = 3
  MAX_TOKEN_AGE = 10.minutes
  CLOCK_SKEW = 60.seconds

  def authorize_params
    super.tap do |params|
      nonce = SecureRandom.urlsafe_base64(32, false)
      session["omniauth.nonce"] = nonce
      params[:nonce] = nonce
    end
  end

  def uid
    verified_id_info.fetch("sub")
  end

  def info
    {}
  end

  def extra
    {}
  end

  private

  def verified_id_info
    @verified_id_info ||=
      begin
        nonce = session.delete("omniauth.nonce").to_s
        raise OmniAuth::Strategies::OAuth2::CallbackError.new(:invalid_nonce, "nonce is missing") if nonce.empty?

        token = access_token.params["id_token"].to_s
        raise OmniAuth::Strategies::OAuth2::CallbackError.new(:invalid_id_token, "ID token is missing") if token.empty?

        payload, = JWT.decode(
          token,
          nil,
          true,
          algorithms: ALLOWED_ALGORITHMS,
          jwks: google_jwks_loader,
          iss: ALLOWED_ISSUERS,
          verify_iss: true,
          aud: options.client_id,
          verify_aud: true,
        )
        verify_google_claims!(payload, expected_nonce: nonce)
        payload.freeze
      rescue JWT::DecodeError, JWT::VerificationError, KeyError, ArgumentError, TypeError => e
        raise OmniAuth::Strategies::OAuth2::CallbackError.new(:invalid_id_token, e.class.name)
      end
  end

  def verify_google_claims!(payload, expected_nonce:)
    subject = payload["sub"].to_s
    nonce = payload["nonce"].to_s
    now = Time.now.to_i
    issued_at = Integer(payload.fetch("iat"))
    expires_at = Integer(payload.fetch("exp"))

    raise JWT::InvalidSubError if subject.empty?
    raise JWT::DecodeError, "nonce mismatch" unless secure_compare(nonce, expected_nonce)
    raise JWT::ExpiredSignature if expires_at <= now - CLOCK_SKEW
    return unless issued_at > now + CLOCK_SKEW || issued_at < now - MAX_TOKEN_AGE - CLOCK_SKEW

    raise JWT::InvalidIatError

  end

  def secure_compare(left, right)
    return false if left.bytesize != right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end

  def google_jwks_loader
    lambda do |loader_options = {}|
      Rails.cache.delete(JWKS_CACHE_KEY) if loader_options[:kid_not_found] || loader_options[:invalidate]
      Rails.cache.fetch(JWKS_CACHE_KEY, expires_in: JWKS_CACHE_TTL) { fetch_google_jwks }
    end
  end

  def fetch_google_jwks
    connection =
      OutboundHttp::Connection.build(
        url: JWKS_URI,
        open_timeout: JWKS_TIMEOUT,
        read_timeout: JWKS_TIMEOUT,
        write_timeout: JWKS_TIMEOUT,
        require_https: true,
      )
    response = connection.get(JWKS_URI)
    raise JWT::DecodeError, "Google JWKS fetch failed" unless response.success?

    jwks = JSON.parse(response.body)
    raise JWT::DecodeError, "Google JWKS has an invalid shape" unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array)

    jwks
  rescue JSON::ParserError, URI::InvalidURIError, *OutboundHttp::Connection::NETWORK_ERRORS => e
    raise JWT::DecodeError, e.class.name
  end
end
