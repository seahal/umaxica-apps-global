# typed: false
# frozen_string_literal: true

module Oidc
  module ClientAssertionJwt
    module_function

    ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
    TOKEN_TYPE = "oidc-client-assertion+jwt"
    TTL = 5.minutes

    def issue(client_id:, token_url:, now: Time.current, jti: SecureRandom.uuid)
      namespace = Oidc::ClientRegistry.jwt_namespace_for(client_id)
      return nil if namespace.blank?

      issuer_id = "oidc_client:#{namespace}"
      payload = {
        "iss" => client_id.to_s,
        "sub" => client_id.to_s,
        "aud" => token_url.to_s,
        "jti" => jti,
        "iat" => now.to_i,
        "exp" => (now + TTL).to_i,
        "typ" => TOKEN_TYPE,
      }

      Jit::Security::Jwt::Keyring.encode(payload, issuer_id: issuer_id)
    rescue Jit::Security::Jwt::Registry::ConfigurationError
      nil
    end

    def valid?(client_id:, assertion:, token_url:, now: Time.current)
      header = Jit::Security::Jwt::Keyring.parse_header(assertion)
      return false unless header["alg"] == Jit::Security::Jwt::Registry::ALGORITHM
      return false unless header["typ"] == TOKEN_TYPE

      namespace = Oidc::ClientRegistry.jwt_namespace_for(client_id)
      return false if namespace.blank?

      public_key = Jit::Security::Jwt::Registry.public_key_for("oidc_client:#{namespace}", header["kid"])
      return false unless public_key

      payload, = JWT.decode(
        assertion,
        public_key,
        true,
        algorithms: [Jit::Security::Jwt::Registry::ALGORITHM],
        required_claims: %w(iss sub aud exp iat jti typ),
        leeway: Authentication::Base::JwtConfiguration.leeway_seconds,
        verify_iat: true,
        verify_exp: true,
        verify_aud: true,
        aud: token_url.to_s,
      )

      payload["iss"] == client_id.to_s &&
        payload["sub"] == client_id.to_s &&
        payload["typ"] == TOKEN_TYPE &&
        now.to_i < payload["exp"].to_i
    rescue JWT::DecodeError, Jit::Security::Jwt::Registry::ConfigurationError
      false
    end
  end
end
