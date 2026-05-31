# typed: false
# frozen_string_literal: true

module Authentication
  # Backward-compatible facade for Auth access JWTs.
  #
  # JWT encode/decode behavior lives in `Security::Jwt::AuthAccessTokenCodec`;
  # this service keeps the existing public API used by controllers and OIDC services.
  class TokenService
    JWT_ALGORITHM = Security::Jwt::AuthAccessTokenCodec::JWT_ALGORITHM
    VALID_ACTOR_TYPES = Security::Jwt::AuthAccessTokenCodec::VALID_ACTOR_TYPES

    class << self
      def encode(...)
        codec.encode(...)
      end

      def decode(...)
        codec.decode(...)
      end

      def decode_allow_expired(...)
        codec.decode_allow_expired(...)
      end

      def extract_session_id_allow_expired(...)
        codec.extract_session_id_allow_expired(...)
      end

      def extract_subject(payload)
        Authorization::TokenClaims.subject(payload)
      end

      def extract_act(payload)
        Authorization::TokenClaims.actor(payload)
      end

      def extract_type(payload)
        extract_act(payload)
      end

      def extract_session_id(payload)
        Authorization::TokenClaims.session_id(payload)
      end

      def extract_jti(payload)
        Authorization::TokenClaims.jti(payload)
      end

      def validate_actor_claim!(payload, expected_act)
        return false if payload.blank?

        act = extract_act(payload)
        return false if act.blank?
        return false unless VALID_ACTOR_TYPES.include?(act)

        act == expected_act
      end

      def extract_scopes(payload)
        Authorization::TokenClaims.scopes(payload)
      end

      def has_scope?(payload, scope)
        scopes = extract_scopes(payload)
        scopes.include?(scope.to_s)
      end

      private

      def codec
        Security::Jwt::AuthAccessTokenCodec
      end
    end
  end
end
