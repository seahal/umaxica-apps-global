# typed: false
# frozen_string_literal: true

module OidcClientAssertionJwt
  module_function

  ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  TOKEN_TYPE = "oidc-client-assertion+jwt"
  TTL = 5.minutes

  class << self
    # Replay tracking store. Defaults to Rails.cache in runtime environments.
    # Tests may inject a real store because Rails.cache is :null_store there.
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_writer :replay_store
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    # rubocop:disable ThreadSafety/ClassInstanceVariable
    def replay_store
      @replay_store ||= Rails.cache
    end
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  end

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

  def valid?(client_id:, assertion:, token_url:, now: Time.current, replay_store: self.replay_store)
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
      now.to_i < payload["exp"].to_i &&
      consume_jti?(
        namespace: namespace,
        client_id: client_id,
        jti: payload["jti"],
        exp: payload["exp"],
        now: now,
        replay_store: replay_store,
      )
  rescue JWT::DecodeError, JitSecurityJwtRegistry::ConfigurationError
    false
  end

  def consume_jti?(namespace:, client_id:, jti:, exp:, now:, replay_store:)
    return false if jti.blank?

    ttl = exp.to_i - now.to_i + AuthenticationJwtConfiguration.leeway_seconds
    return false unless ttl.positive?

    replay_store.write(
      replay_cache_key(namespace: namespace, client_id: client_id, jti: jti),
      true,
      expires_in: ttl.seconds,
      unless_exist: true,
    )
  rescue StandardError => e
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.client_assertion.replay_store_unavailable",
        op: "write",
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    false
  end

  def replay_cache_key(namespace:, client_id:, jti:)
    "oidc:client_assertion:#{namespace}:#{client_id}:jti:#{jti}"
  end

  private_class_method :consume_jti?, :replay_cache_key
end
