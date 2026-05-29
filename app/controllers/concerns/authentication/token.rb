# typed: false
# frozen_string_literal: true

module Authentication
  # Thin facade over `Authentication::TokenService` for the encode /
  # decode / claim-extraction operations. Lives here (and not in
  # `TokenService` itself) so callers can name the high-level operation
  # without coupling to the service's internal structure.
  #
  # Previously a nested class inside `Authentication::Base`. Extracted
  # for the same reason as `JwtConfiguration`. Existing references via
  # `Authentication::Base::Token` keep working through the alias defined
  # in `Authentication::Base`.
  class Token
    JWT_ALGORITHM = "ES384"

    class << self
      def encode(resource, host:, session_public_id: nil, session_id: nil, oidc_sid: nil, oidc_jti: nil,
                 resource_type: nil, dpop_jkt: nil, expires_at: nil, preferences: nil, acr: nil, amr: nil,
                 jwt_issuer_id: nil)
        Authentication::TokenService.encode(
          resource, host: host, session_public_id: session_public_id, session_id: session_id,
                    oidc_sid: oidc_sid, oidc_jti: oidc_jti, resource_type: resource_type, dpop_jkt: dpop_jkt,
                    expires_at: expires_at, preferences: preferences, acr: acr, amr: amr,
                    jwt_issuer_id: jwt_issuer_id,
        )
      end

      def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil, jwt_issuer_id: nil)
        Authentication::TokenService.decode(
          token, host: host, resource_type: resource_type, issuer: issuer,
                 audiences: audiences, jwt_issuer_id: jwt_issuer_id,
        )
      end

      def extract_subject(payload)
        Authentication::TokenService.extract_subject(payload)
      end

      def extract_act(payload)
        Authentication::TokenService.extract_act(payload)
      end

      def extract_type(payload)
        Authentication::TokenService.extract_type(payload)
      end

      def validate_actor_claim!(payload, expected_act)
        Authentication::TokenService.validate_actor_claim!(payload, expected_act)
      end

      def extract_session_id(payload)
        Authentication::TokenService.extract_session_id(payload)
      end

      def extract_session_id_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil,
                                           jwt_issuer_id: nil)
        Authentication::TokenService.extract_session_id_allow_expired(
          token,
          host: host,
          resource_type: resource_type,
          issuer: issuer,
          audiences: audiences,
          jwt_issuer_id: jwt_issuer_id,
        )
      end

      def extract_jti(payload)
        Authentication::TokenService.extract_jti(payload)
      end
    end
  end
end
