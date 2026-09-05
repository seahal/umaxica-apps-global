# typed: false
# frozen_string_literal: true

module OidcClientAssertionJwt
  module_function

  ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  TOKEN_TYPE = "oidc-client-assertion+jwt"
  TTL = 5.minutes

  class << self
    # Tests may inject a deterministic store. Runtime replay prevention is
    # PostgreSQL-backed because losing a consumed JTI would weaken security.
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_writer :replay_store
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    # rubocop:disable ThreadSafety/ClassInstanceVariable
    def replay_store
      @replay_store ||= SecurityConsumedJti
    end
    # rubocop:enable ThreadSafety/ClassInstanceVariable
  end

  def issue(client_id:, token_url:, now: Time.current, jti: SecureRandom.uuid)
    issue_with_configured_key(client_id: client_id, token_url: token_url, now: now, jti: jti)
  rescue JitSecurityJwtRegistry::ConfigurationError
    return nil unless refresh_local_key_material!(client_id: client_id)

    begin
      issue_with_configured_key(client_id: client_id, token_url: token_url, now: now, jti: jti)
    rescue JitSecurityJwtRegistry::ConfigurationError
      nil
    end
  end

  def issue_with_configured_key(client_id:, token_url:, now:, jti:)
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

    if replay_store == SecurityConsumedJti
      replay_store.consume!(
        purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_client_assertion),
        issuer: "#{namespace}:#{client_id}",
        jti: jti,
        expires_at: now + ttl.seconds,
      )
    else
      replay_store.write(
        replay_cache_key(namespace: namespace, client_id: client_id, jti: jti),
        true,
        expires_in: ttl.seconds,
        unless_exist: true,
      )
    end
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

  def refresh_local_key_material!(client_id:)
    return false unless Rails.env.local?
    return false unless defined?(JitSecurityJwtLocalKeysetInstaller)

    namespace = OidcClientRegistry.jwt_namespace_for(client_id)
    return false if namespace.blank?

    JitSecurityJwtLocalKeysetInstaller.install!
    JitSecurityJwtRegistry.reload!
    JitSecurityJwtRegistry.private_key_for("oidc_client:#{namespace}").present?
  end

  private_class_method :issue_with_configured_key, :consume_jti?, :replay_cache_key, :refresh_local_key_material!
end
