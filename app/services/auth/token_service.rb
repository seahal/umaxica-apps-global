# typed: false
# frozen_string_literal: true

require "jwt"

module Auth
  class TokenService
    JWT_ALGORITHM = "ES384"
    VALID_ACTOR_TYPES = %w(user staff customer).freeze

    class << self
      def encode(resource, host:, session_public_id: nil, resource_type: nil, expires_at: nil, preferences: nil,
                 acr: nil, amr: nil)
        return nil unless valid_encode_params?(resource, host)

        type = resource_type || resource.class.name.downcase
        payload = build_payload(
          resource, session_public_id, type, expires_at: expires_at, preferences: preferences,
                                             acr: acr, amr: amr,
        )
        token_type = Authentication::Base::JwtConfiguration.token_type(type)
        JWT.encode(
          payload,
          Jit::Security::Jwt::Keyring.private_key_for_active,
          JWT_ALGORITHM,
          { kid: Jit::Security::Jwt::Keyring.active_kid, typ: token_type },
        )
      rescue JWT::EncodeError, OpenSSL::PKey::PKeyError, ArgumentError => e
        Rails.event.notify(
          "authentication.token.generation.failed",
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(5),
          resource_type: resource.class.name,
          resource_id: resource.id,
        )
        nil
      end

      def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil)
        return nil if token.blank? || host.blank?

        header = Jit::Security::Jwt::Keyring.parse_header(token)
        unless valid_header?(header, resource_type)
          report_invalid_header(resource_type: resource_type, host: host, header: header)
          return nil
        end

        public_key = Jit::Security::Jwt::Keyring.public_key_for(header["kid"])
        if public_key.nil?
          Jit::Security::Jwt::AnomalyReporter.report_auth(
            resource_type: resource_type,
            host: host,
            header: header,
            reason: "UNKNOWN_KID",
          )
          return nil
        end

        payload, = JWT.decode(token, public_key, true, decode_options(resource_type, issuer, audiences))
        unless valid_payload_type?(payload, resource_type)
          Jit::Security::Jwt::AnomalyReporter.report_auth(
            resource_type: resource_type,
            host: host,
            header: header,
            payload: payload,
            reason: "TYP_MISMATCH",
          )
          return nil
        end

        payload
      rescue JWT::ExpiredSignature
        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "EXPIRED",
        )
        Rails.event.notify("authentication.token.verification.expired", host: host)
        nil
      rescue JWT::InvalidIssuerError, JWT::InvalidAudError, JWT::InvalidIatError, JWT::ImmatureSignature => e
        report_claim_error(resource_type: resource_type, host: host, header: header, error: e)
        Rails.event.notify(
          "authentication.token.verification.claim_invalid",
          error_class: e.class.name,
          host: host,
        )
        nil
      rescue JWT::DecodeError, JWT::VerificationError => e
        report_decode_error(resource_type: resource_type, host: host, header: header, error: e)
        Rails.event.notify(
          "authentication.token.verification.failed",
          error_class: e.class.name,
          host: host,
        )
        nil
      rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
        Rails.event.notify(
          "authentication.token.verification.error",
          error_class: e.class.name,
          error_message: e.message,
          host: host,
        )
        nil
      end

      def extract_subject(payload)
        Auth::TokenClaims.subject(payload)
      end

      def extract_act(payload)
        Auth::TokenClaims.actor(payload)
      end

      def extract_type(payload)
        extract_act(payload)
      end

      def extract_session_id(payload)
        Auth::TokenClaims.session_id(payload)
      end

      def extract_jti(payload)
        Auth::TokenClaims.jti(payload)
      end

      def validate_actor_claim!(payload, expected_act)
        return false if payload.blank?

        act = extract_act(payload)
        return false if act.blank?
        return false unless VALID_ACTOR_TYPES.include?(act)

        act == expected_act
      end

      def extract_scopes(payload)
        Auth::TokenClaims.scopes(payload)
      end

      def has_scope?(payload, scope)
        scopes = extract_scopes(payload)
        scopes.include?(scope.to_s)
      end

      private

      def valid_encode_params?(resource, host)
        return false if resource.nil? || host.blank?
        return false unless resource.respond_to?(:id)
        return false if resource.id.blank?

        true
      end

      def build_payload(resource, session_public_id, type, expires_at: nil, preferences: nil, acr: nil, amr: nil)
        Auth::TokenClaims.build(
          resource: resource,
          session_public_id: session_public_id,
          resource_type: type,
          issued_at: Time.current,
          access_token_ttl: Authentication::Base::ACCESS_TOKEN_TTL,
          expires_at: expires_at,
          preferences: preferences,
          acr: acr,
          amr: amr,
        )
      end

      def decode_options(resource_type, issuer, audiences)
        {
          algorithms: [JWT_ALGORITHM],
          required_claims: %w(iss aud typ exp sub sid act jti acr),
          leeway: Authentication::Base::JwtConfiguration.leeway_seconds,
          verify_iat: true,
          verify_exp: true,
          verify_iss: true,
          iss: issuer || Authentication::Base::JwtConfiguration.issuer(resource_type),
          verify_aud: true,
          aud: audiences || Authentication::Base::JwtConfiguration.audiences(resource_type),
        }
      end

      def valid_header?(header, resource_type)
        return false if header.blank?
        return false unless header["alg"] == JWT_ALGORITHM
        return false unless header["typ"] == expected_token_type(resource_type)

        header["kid"].present?
      end

      def valid_payload_type?(payload, resource_type)
        payload.is_a?(Hash) && payload["typ"] == expected_token_type(resource_type)
      end

      def expected_token_type(resource_type)
        Authentication::Base::JwtConfiguration.token_type(resource_type)
      end

      def report_invalid_header(resource_type:, host:, header:)
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

        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: reason,
        )
      end

      def report_claim_error(resource_type:, host:, header:, error:)
        reason =
          case error
          when JWT::InvalidIssuerError then "ISS_MISMATCH"
          when JWT::InvalidAudError then "AUD_MISMATCH"
          when JWT::InvalidIatError then "IAT_INVALID"
          when JWT::ImmatureSignature then "IMMATURE"
          else "OTHER"
          end

        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: reason,
          error: error,
        )
      end

      def report_decode_error(resource_type:, host:, header:, error:)
        reason =
          if error.is_a?(JWT::VerificationError)
            "SIGNATURE_INVALID"
          elsif error.message.to_s.include?("Missing required claim")
            Jit::Security::Jwt::AnomalyReporter.reason_for_missing_claim(error.message)
          elsif error.message.to_s.match?(/Not enough or too many segments|Invalid segment encoding/)
            "MALFORMED_TOKEN"
          else
            "DECODE_ERROR"
          end

        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: reason,
          error: error,
        )
      end
    end
  end
end
