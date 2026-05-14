# typed: false
# frozen_string_literal: true

require "jwt"

module Auth
  class TokenService
    JWT_ALGORITHM = "ES384"
    VALID_ACTOR_TYPES = %w(user operator visitor).freeze

    class << self
      def encode(resource, host:, resource_type: nil, dpop_jkt: nil, expires_at: nil,
                 session_public_id: nil, session_id: nil, preferences: nil,
                 scopes: nil, acr: nil, amr: nil, access_token_ttl: 1.hour)
        resource_type ||=
          case resource
          when User then "user"
          when Operator then "operator"
          when Visitor then "visitor"
          end

        return nil unless valid_encode_params?(resource, host)

        issued_at = Time.current
        payload = Auth::TokenClaims.build(
          resource: resource,
          session_id: session_id,
          session_public_id: session_public_id,
          resource_type: resource_type,
          issued_at: issued_at,
          access_token_ttl: access_token_ttl,
          expires_at: expires_at,
          preferences: preferences,
          scopes: scopes,
          acr: acr,
          amr: amr,
          dpop_jkt: dpop_jkt,
        )

        Jit::Security::Jwt::Keyring.encode(payload)
      rescue StandardError => e
        Rails.logger.error("Token encoding failed: #{e.message}")
        Rails.event.notify(
          "authentication.token.encoding.error",
          resource_type: resource_type,
          resource_id: resource&.id,
        )
        nil
      end

      def decode(token, host:, resource_type: nil, issuer: nil, audiences: nil)
        decode_with_expiration(
          token, host: host, resource_type: resource_type, issuer: issuer,
                 audiences: audiences, verify_exp: true,
        )
      end

      def decode_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil)
        decode_with_expiration(
          token, host: host, resource_type: resource_type, issuer: issuer,
                 audiences: audiences, verify_exp: false,
        )
      end

      def extract_session_id_allow_expired(token, host:, resource_type: nil, issuer: nil, audiences: nil)
        payload = decode_allow_expired(
          token, host: host, resource_type: resource_type,
                 issuer: issuer, audiences: audiences,
        )
        Auth::TokenClaims.session_id(payload) if payload.present?
      end

      def decode_with_expiration(token, host:, resource_type: nil, issuer: nil, audiences: nil, verify_exp:)
        return nil if token.blank? || host.blank?

        header = Jit::Security::Jwt::Keyring.parse_header(token)
        unless valid_header?(header, resource_type)
          # puts "DEBUG: valid_header? failed for typ #{header["typ"].inspect}"
          report_invalid_header(resource_type: resource_type, host: host, header: header)
          return nil
        end

        public_key = Jit::Security::Jwt::Keyring.public_key_for(header["kid"])
        if public_key.nil?
          # puts "DEBUG: public_key_for failed for kid #{header["kid"].inspect}"
          Jit::Security::Jwt::AnomalyReporter.report_auth(
            resource_type: resource_type,
            host: host,
            header: header,
            reason: "UNKNOWN_KID",
          )
          return nil
        end

        payload, = JWT.decode(
          token, public_key, true,
          decode_options(resource_type, issuer, audiences, verify_exp: verify_exp),
        )
        unless valid_payload_type?(payload, resource_type)
          # puts "DEBUG: valid_payload_type? failed for typ #{payload["typ"].inspect}"
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
        return nil unless verify_exp

        # STDOUT.puts "DEBUG: token expired"
        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "EXPIRED",
        )
        Rails.event.notify("authentication.token.verification.expired", host: host)
        nil
      rescue JWT::InvalidIssuerError, JWT::InvalidAudError, JWT::InvalidIatError, JWT::ImmatureSignature => e
        # STDOUT.puts "DEBUG: claim error: #{e.class} - #{e.message}"
        report_claim_error(resource_type: resource_type, host: host, header: header, error: e)
        Rails.event.notify(
          "authentication.token.verification.claim_invalid",
          error_class: e.class.name,
          host: host,
        )
        nil
      rescue JWT::DecodeError, JWT::VerificationError => e
        # STDOUT.puts "DEBUG: decode error: #{e.class} - #{e.message}"
        report_decode_error(resource_type: resource_type, host: host, header: header, error: e)
        Rails.event.notify(
          "authentication.token.verification.failed",
          error_class: e.class.name,
          host: host,
        )
        nil
      rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError => e
        # STDOUT.puts "DEBUG: general error: #{e.class} - #{e.message}"
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

        # Ensure resource is User, Operator or Visitor
        resource.is_a?(User) || resource.is_a?(Operator) || resource.is_a?(Visitor)
      end

      def decode_options(resource_type, issuer, audiences, verify_exp:)
        {
          algorithms: [JWT_ALGORITHM],
          required_claims: %w(iss aud typ exp sub sid act jti acr),
          leeway: Authentication::Base::JwtConfiguration.leeway_seconds,
          verify_iat: true,
          verify_exp: verify_exp,
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
        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "INVALID_HEADER",
        )
      end

      def report_claim_error(resource_type:, host:, header:, error:)
        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "CLAIM_INVALID",
          error: error,
        )
      end

      def report_decode_error(resource_type:, host:, header:, error:)
        Jit::Security::Jwt::AnomalyReporter.report_auth(
          resource_type: resource_type,
          host: host,
          header: header,
          reason: "DECODE_FAILED",
          error: error,
        )
      end
    end
  end
end
