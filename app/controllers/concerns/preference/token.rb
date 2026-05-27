# typed: false
# frozen_string_literal: true

require "jwt"

module Preference
  # ES384-signed access token for preference state. Encodes a payload of
  # user-selected preference values plus public_id/jti so the cookie can be
  # rotated and invalidated server-side without a DB round-trip.
  class Token
    JWT_ALGORITHM = "ES384"
    ACCESS_TOKEN_TTL = 7.days
    TOKEN_TYPE = "preference-access-token"

    class << self
      def encode(preferences, host:, preference_type:, public_id:, jti:)
        return nil unless valid_encode_params?(preferences, host, preference_type, public_id, jti)

        payload = build_payload(preferences, host, preference_type, public_id, jti)
        JWT.encode(
          payload,
          JwtConfiguration.private_key_for_active,
          JWT_ALGORITHM,
          { kid: JwtConfiguration.active_kid, typ: TOKEN_TYPE },
        )
      rescue StandardError => e
        Rails.logger.error("PreferenceToken.encode failed: #{e.message}")
        nil
      end

      def decode(token, host:)
        return nil if token.blank? || host.blank?

        header = JwtConfiguration.parse_header(token)
        unless valid_header?(header)
          report_invalid_header(host: host, header: header)
          return nil
        end

        public_key = JwtConfiguration.public_key_for(header["kid"])
        if public_key.nil?
          Jit::Security::Jwt::AnomalyReporter.report_preference(
            host: host,
            header: header,
            reason: "UNKNOWN_KID",
          )
          return nil
        end

        payload, = JWT.decode(token, public_key, true, decode_options)
        validated_payload = validate_payload(payload, host)
        unless validated_payload
          report_invalid_payload(host: host, header: header, payload: payload)
          return nil
        end

        validated_payload
      rescue JWT::ExpiredSignature
        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          reason: "EXPIRED",
        )
        Rails.logger.debug("PreferenceToken.decode failed: token expired")
        nil
      rescue JWT::InvalidIssuerError, JWT::InvalidIatError, JWT::ImmatureSignature => e
        report_claim_error(host: host, header: header, error: e)
        Rails.logger.debug { "PreferenceToken.decode invalid claims: #{e.class}: #{e.message}" }
        nil
      rescue JWT::DecodeError, JWT::VerificationError => e
        report_decode_error(host: host, header: header, error: e)
        Rails.logger.debug { "PreferenceToken.decode invalid token: #{e.message}" }
        nil
      rescue StandardError => e
        Rails.logger.error("PreferenceToken.decode failed: #{e.message}")
        nil
      end

      def extract_preferences(payload)
        return {} unless payload.is_a?(Hash)

        payload["preferences"] || {}
      end

      def extract_public_id(payload)
        payload&.dig("public_id")
      end

      def extract_preference_type(payload)
        payload&.dig("preference_type")
      end

      def extract_jti(payload)
        payload&.dig("jti")
      end

      private

      def valid_encode_params?(preferences, host, preference_type, public_id, jti)
        [preferences, host, preference_type, public_id, jti].all?(&:present?)
      end

      def build_payload(preferences, host, preference_type, public_id, jti)
        now = Time.current.to_i
        {
          preferences: preferences,
          host: JwtConfiguration.host_scope_for(host),
          preference_type: preference_type,
          public_id: public_id,
          jti: jti,
          typ: TOKEN_TYPE,
          iss: JwtConfiguration.issuer,
          aud: JwtConfiguration.audience_for(host),
          iat: now,
          exp: now + Integer(ACCESS_TOKEN_TTL.to_s, 10),
        }
      end

      def decode_options
        {
          algorithms: [JWT_ALGORITHM],
          required_claims: %w(iss aud typ exp public_id jti preference_type),
          leeway: JwtConfiguration.leeway_seconds,
          verify_iss: true,
          iss: JwtConfiguration.issuer,
          verify_aud: false,
          verify_iat: true,
          verify_exp: true,
        }
      end

      def validate_payload(payload, host)
        return nil unless payload.is_a?(Hash)
        return nil unless payload["typ"] == TOKEN_TYPE
        return nil unless host_matches?(payload["host"], host)
        return nil unless audience_matches?(payload["aud"], host)

        payload
      end

      def valid_header?(header)
        return false if header.blank?
        return false unless header["alg"] == JWT_ALGORITHM
        return false if header["kid"].blank?

        header["typ"] == TOKEN_TYPE
      end

      def report_invalid_header(host:, header:)
        reason =
          if header.blank? || header["alg"].blank?
            "MALFORMED_TOKEN"
          elsif header["kid"].blank?
            "MISSING_KID"
          elsif header["alg"] == "none"
            "ALG_NONE"
          elsif header["alg"] != JWT_ALGORITHM
            "ALG_MISMATCH"
          elsif header["typ"].blank?
            "MISSING_TYP"
          else
            "TYP_MISMATCH"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(host: host, header: header, reason: reason)
      end

      def report_invalid_payload(host:, header:, payload:)
        reason =
          if payload["typ"] != TOKEN_TYPE
            "TYP_MISMATCH"
          elsif payload["host"].blank? || !host_matches?(payload["host"], host)
            "HOST_MISMATCH"
          elsif !audience_matches?(payload["aud"], host)
            "AUD_MISMATCH"
          else
            "OTHER"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          payload: payload,
          reason: reason,
        )
      end

      def report_claim_error(host:, header:, error:)
        reason =
          case error
          when JWT::InvalidIssuerError then "ISS_MISMATCH"
          when JWT::InvalidIatError then "IAT_INVALID"
          when JWT::ImmatureSignature then "IMMATURE"
          else "OTHER"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          reason: reason,
          error: error,
        )
      end

      def report_decode_error(host:, header:, error:)
        reason =
          if error.message.to_s.include?("Missing required claim")
            Jit::Security::Jwt::AnomalyReporter.reason_for_missing_claim(error.message)
          elsif error.message.to_s.include?("Signature verification failed")
            "SIGNATURE_INVALID"
          elsif error.message.to_s.match?(/Not enough or too many segments|Invalid segment encoding/)
            "MALFORMED_TOKEN"
          else
            "DECODE_ERROR"
          end

        Jit::Security::Jwt::AnomalyReporter.report_preference(
          host: host,
          header: header,
          reason: reason,
          error: error,
        )
      end

      def host_matches?(host_claim, host)
        return false if host_claim.blank?

        host == host_claim || host.end_with?(".#{host_claim}")
      end

      def audience_matches?(aud_claim, host)
        normalize_audiences(aud_claim).any? do |aud|
          host == aud || host.end_with?(".#{aud}")
        end
      end

      def normalize_audiences(aud_claim)
        case aud_claim
        when Array then aud_claim
        when String then [aud_claim]
        else []
        end
      end
    end
  end
end
