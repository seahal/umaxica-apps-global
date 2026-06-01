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

      # Test-facing delegators. The security-critical claim/header helpers were
      # moved into the codec as private methods during the encode/decode
      # extraction. The facade re-exposes them (privately) so the existing unit
      # tests can keep exercising each helper in isolation via `send`, without
      # widening the codec's public surface.
      def normalize_audiences(...) = codec.send(:normalize_audiences, ...)

      def valid_header?(...) = codec.send(:valid_header?, ...)

      def host_matches?(...) = codec.send(:host_matches?, ...)

      def audience_matches?(...) = codec.send(:audience_matches?, ...)

      def validate_payload(...) = codec.send(:validate_payload, ...)

      def report_invalid_header(...) = codec.send(:report_invalid_header, ...)

      def report_invalid_payload(...) = codec.send(:report_invalid_payload, ...)

      def report_claim_error(...) = codec.send(:report_claim_error, ...)

      def report_decode_error(...) = codec.send(:report_decode_error, ...)

      def codec
        Security::Jwt::PreferenceTokenCodec
      end
    end
  end
end
