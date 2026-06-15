# typed: false
# frozen_string_literal: true

class OidcLogoutTokenCodec
  JWT_ALGORITHM = "ES384"
  TOKEN_TYPE = "logout+jwt"
  EVENT_CLAIM = "http://schemas.openid.net/event/backchannel-logout"
  REPLAY_TTL = 10.minutes

  Result =
    Data.define(:success, :payload, :error) do
      def success? = success
    end

  class << self
    def encode(client_id:, resource_type:, subject:, sid:, issued_at: Time.current)
      payload = {
        "iss" => OidcIssuer.for_resource_type(resource_type),
        "aud" => client_id.to_s,
        "iat" => Integer(issued_at.to_i),
        "jti" => JitSecurityJwtJtiGenerator.generate,
        "typ" => TOKEN_TYPE,
        "events" => { EVENT_CLAIM => {} },
      }
      payload["sub"] = subject.to_s if subject.present?
      payload["sid"] = sid.to_s if sid.present?
      raise ArgumentError, "logout token requires sid or subject" if payload["sid"].blank? && payload["sub"].blank?

      JitSecurityJwtKeyring.encode(
        payload,
        issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      )
    end

    def decode(logout_token:, client_id:, resource_type:, replay_store: Rails.cache)
      payload = decode_payload!(
        logout_token: logout_token,
        client_id: client_id,
        resource_type: resource_type,
      )
      validate_payload!(payload)
      consume_jti!(payload.fetch("jti"), replay_store)

      Result.new(success: true, payload: payload, error: nil)
    rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError, KeyError
      Result.new(success: false, payload: nil, error: "invalid_logout_token")
    end

    private

    def decode_payload!(logout_token:, client_id:, resource_type:)
      header = JitSecurityJwtKeyring.parse_header(logout_token)
      raise JWT::DecodeError, "invalid alg" unless header["alg"] == JWT_ALGORITHM
      raise JWT::DecodeError, "invalid typ" unless header["typ"] == TOKEN_TYPE

      public_key = JitSecurityJwtKeyring.public_key_for(
        header["kid"],
        issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      )
      raise JWT::DecodeError, "unknown kid" unless public_key

      payload, = JWT.decode(
        logout_token,
        public_key,
        true,
        algorithms: [JWT_ALGORITHM],
        required_claims: %w(iss aud iat jti typ events),
        leeway: AuthenticationJwtConfiguration.leeway_seconds,
        verify_iat: true,
        verify_iss: true,
        iss: OidcIssuer.for_resource_type(resource_type),
        verify_aud: true,
        aud: client_id.to_s,
      )
      payload
    end

    def validate_payload!(payload)
      raise JWT::DecodeError, "invalid typ" unless payload["typ"] == TOKEN_TYPE
      raise JWT::DecodeError, "nonce forbidden" if payload.key?("nonce")
      raise JWT::DecodeError, "sid or sub required" if payload["sid"].blank? && payload["sub"].blank?

      events = payload["events"]
      raise JWT::DecodeError, "invalid events" unless events.is_a?(Hash) && events.key?(EVENT_CLAIM)
    end

    def consume_jti!(jti, replay_store)
      key = "oidc:logout_token:jti:#{jti}"
      raise JWT::DecodeError, "replayed jti" if replay_store.exist?(key)

      replay_store.write(key, true, expires_in: REPLAY_TTL)
    end
  end
end
