# typed: false
# frozen_string_literal: true

module OidcClientAssertionJwt
  module_function

  ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  TOKEN_TYPE = "oidc-client-assertion+jwt"
  TTL = 5.minutes

  def issue(client_id:, token_url:, now: Time.current, jti: SecureRandom.uuid)
    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
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

    JitSecurityJwtKeyring.encode(payload, issuer_id: issuer_id)
  rescue JitSecurityJwtRegistry::ConfigurationError
    nil
  end

  def valid?(client_id:, assertion:, token_url:, now: Time.current)
    header = JitSecurityJwtKeyring.parse_header(assertion)
    return false unless header["alg"] == JitSecurityJwtRegistry::ALGORITHM
    return false unless header["typ"] == TOKEN_TYPE

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return false if namespace.blank?

    public_key = JitSecurityJwtRegistry.public_key_for("oidc_client:#{namespace}", header["kid"])
    return false unless public_key

    payload, = JWT.decode(
      assertion,
      public_key,
      true,
      algorithms: [JitSecurityJwtRegistry::ALGORITHM],
      required_claims: %w(iss sub aud exp iat jti typ),
      leeway: AuthenticationJwtConfiguration.leeway_seconds,
      verify_iat: true,
      verify_exp: true,
      verify_aud: true,
      aud: token_url.to_s,
    )

    payload["iss"] == client_id.to_s &&
      payload["sub"] == client_id.to_s &&
      payload["typ"] == TOKEN_TYPE &&
      now.to_i < payload["exp"].to_i
  rescue JWT::DecodeError, JitSecurityJwtRegistry::ConfigurationError
    false
  end
end
