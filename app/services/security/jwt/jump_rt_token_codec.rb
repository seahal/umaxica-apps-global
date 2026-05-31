# typed: false
# frozen_string_literal: true

module Security
  module Jwt
    class JumpRtTokenCodec
      ALGORITHM = "ES384"
      TOKEN_TYPE = "JWT"
      TOKEN_SUBJECT = "jump-redirect"
      REQUIRED_JWK_FIELDS = Jit::Security::Jwt::Jwk::REQUIRED_PUBLIC_FIELDS
      PRIVATE_JWK_FIELDS = Jit::Security::Jwt::Jwk::PRIVATE_FIELDS

      class << self
        def encode(payload, private_key:, kid:)
          JWT.encode(
            payload,
            private_key,
            ALGORITHM,
            { typ: TOKEN_TYPE, kid: kid },
          )
        end

        def build_issue_payload(namespace:, normalized_url:, dst:, replay_policy:, ttl:, now:, jti:, audience:)
          issued_at = now.to_i
          {
            schema: 1,
            iss: JumpRt::Surface.issuer_origin(namespace),
            aud: audience,
            sub: TOKEN_SUBJECT,
            iat: issued_at,
            nbf: issued_at,
            exp: issued_at + ttl.to_i,
            jti: jti,
            dst: dst,
            rpl: replay_policy,
            url: normalized_url,
          }
        end

        def valid_header?(header)
          return false unless header["typ"] == TOKEN_TYPE
          return false unless header["alg"] == ALGORITHM
          return false if header["kid"].blank?
          return false if %w(crit jku jwk x5u).any? { |key| header.key?(key) }

          true
        end

        def decode_with_key(token:, key:, issuer:, audience:, leeway:)
          payload, = JWT.decode(
            token,
            key,
            true,
            algorithms: [ALGORITHM],
            required_claims: %w(schema iss aud sub iat nbf exp jti src dst url),
            leeway: leeway,
            verify_iat: true,
            verify_exp: true,
            verify_iss: true,
            iss: issuer,
            verify_aud: true,
            aud: audience,
          )
          payload
        end

        def normalized_public_jwk(entry)
          Jit::Security::Jwt::Jwk.normalize_public(entry)
        rescue Jit::Security::Jwt::Jwk::Error
          nil
        end
      end
    end
  end
end
