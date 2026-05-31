# typed: false
# frozen_string_literal: true

require "jwt"

module Preference
  # Backward-compatible facade for preference JWT access tokens.
  #
  # Token encoding/decoding lives in `Security::Jwt::PreferenceTokenCodec`;
  # this class keeps the existing public API and test-facing helper methods.
  class Token
    JWT_ALGORITHM = Security::Jwt::PreferenceTokenCodec::JWT_ALGORITHM
    ACCESS_TOKEN_TTL = Security::Jwt::PreferenceTokenCodec::ACCESS_TOKEN_TTL
    TOKEN_TYPE = Security::Jwt::PreferenceTokenCodec::TOKEN_TYPE

    class << self
      def encode(preferences, host:, preference_type:, public_id:, jti:, jwt_issuer_id: nil)
        codec.encode(
          preferences,
          host: host,
          preference_type: preference_type,
          public_id: public_id,
          jti: jti,
          jwt_issuer_id: jwt_issuer_id,
        )
      end

      def decode(token, host:, jwt_issuer_id: nil)
        codec.decode(token, host: host, jwt_issuer_id: jwt_issuer_id)
      end

      def extract_preferences(payload) = codec.extract_preferences(payload)

      def extract_public_id(payload) = codec.extract_public_id(payload)

      def extract_preference_type(payload) = codec.extract_preference_type(payload)

      def extract_jti(payload) = codec.extract_jti(payload)

      private

      def codec
        Security::Jwt::PreferenceTokenCodec
      end
    end
  end
end
