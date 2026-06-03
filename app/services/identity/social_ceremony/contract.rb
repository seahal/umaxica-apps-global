# typed: false
# frozen_string_literal: true

require "jwt"

module Identity
  module SocialCeremony
    Error = Class.new(StandardError)

    module Contract
      module_function

      ALGORITHM = "ES384"
      SURFACES = %w(app).freeze
      OPERATIONS = %w(link login signup account_selection).freeze
      PROVIDERS = %w(apple google_app).freeze
      LEEWAY = 30

      SIGN_ISSUERS = {
        "app" => "https://id.umaxica.app",
      }.freeze

      ACME_ISSUERS = {
        "app" => "https://www.umaxica.app",
      }.freeze

      SIGN_AUDIENCES = {
        "app" => "https://id.umaxica.app/social-ceremony",
      }.freeze

      ACME_AUDIENCES = {
        "app" => "https://www.umaxica.app/social-ceremony-result",
      }.freeze

      FORBIDDEN_KEYS = %w(
        access_token
        auth_token
        authorization
        delegated_authorization
        downstream_token
        id_token
        raw_email
        recent_auth
        refresh_token
        session_token
        step_up_freshness
        sudo
        token
      ).freeze

      def sign_issuer(surface) = fetch_surface_value(SIGN_ISSUERS, surface)

      def acme_issuer(surface) = fetch_surface_value(ACME_ISSUERS, surface)

      def sign_audience(surface) = fetch_surface_value(SIGN_AUDIENCES, surface)

      def acme_audience(surface) = fetch_surface_value(ACME_AUDIENCES, surface)

      def sign_issuer_id(surface) = "surface:SIGN_#{surface.to_s.upcase}"

      def acme_issuer_id(surface) = "surface:ACME_#{surface.to_s.upcase}"

      def provider_subject_digest(provider:, subject:)
        Digest::SHA256.hexdigest("#{SocialIdentifiable.normalize_provider(provider)}:#{subject}")
      end

      def fetch_surface_value(values, surface)
        values.fetch(surface.to_s)
      rescue KeyError
        raise Error, "surface is invalid"
      end

      def validate_common_payload!(payload, required:, allowed:, purpose:, audience:, issuer:, now:)
        validate_keys!(payload, allowed: allowed)
        validate_required!(payload, required)
        validate_exact!(payload, "iss", issuer)
        validate_exact!(payload, "aud", audience)
        validate_exact!(payload, "purpose", purpose)
        validate_inclusion!(payload, "surface", SURFACES)
        validate_inclusion!(payload, "operation", OPERATIONS)
        validate_inclusion!(payload, "provider", PROVIDERS)
        validate_timestamp!(payload, "iat")
        validate_future_timestamp!(payload, "exp", now: now) if payload.key?("exp")
        validate_future_timestamp!(payload, "expires_at", now: now) if payload.key?("expires_at")
        validate_binding!(payload)
      end

      def validate_keys!(payload, allowed:)
        keys = payload.keys.map(&:to_s)
        forbidden = keys & FORBIDDEN_KEYS
        raise Error, "forbidden claims: #{forbidden.sort.join(", ")}" if forbidden.present?

        unknown = keys - allowed
        raise Error, "unknown claims: #{unknown.sort.join(", ")}" if unknown.present?
      end

      def validate_required!(payload, required)
        missing = required.reject { |key| payload[key].present? }
        raise Error, "missing required claims: #{missing.join(", ")}" if missing.present?
      end

      def validate_exact!(payload, key, expected)
        raise Error, "#{key} is invalid" unless payload[key].to_s == expected.to_s
      end

      def validate_inclusion!(payload, key, allowed)
        raise Error, "#{key} is invalid" unless allowed.include?(payload[key].to_s)
      end

      def validate_binding!(payload)
        raise Error, "actor_ref is required" if payload["actor_ref"].blank?
        raise Error, "session_ref is required" if payload["session_ref"].blank?
      end

      def validate_timestamp!(payload, key)
        Integer(payload[key])
      rescue ArgumentError, TypeError
        raise Error, "#{key} must be an integer timestamp"
      end

      def validate_future_timestamp!(payload, key, now:)
        value = Integer(payload[key])
        raise Error, "#{key} is expired" unless value > now.to_i
      rescue ArgumentError, TypeError
        raise Error, "#{key} must be an integer timestamp"
      end

      def validate_header!(header, expected_type:)
        raise Error, "header is invalid" if header.blank?
        raise Error, "alg is invalid" unless header["alg"] == ALGORITHM
        raise Error, "typ is invalid" unless header["typ"] == expected_type
        raise Error, "kid is required" if header["kid"].blank?
        raise Error, "unsafe header is forbidden" if %w(crit jku jwk x5u).any? { |key| header.key?(key) }
      end

      def decode_unverified_payload(token)
        payload, = JWT.decode(token, nil, false)
        payload
      rescue JWT::DecodeError => e
        raise Error, "token is invalid: #{e.message}"
      end

      def decode_verified_payload(token:, issuer_id:, issuer:, audience:, expected_type:, required:)
        header = Jit::Security::Jwt::Keyring.parse_header(token)
        validate_header!(header, expected_type: expected_type)

        public_key = Jit::Security::Jwt::Keyring.public_key_for(header["kid"], issuer_id: issuer_id)
        raise Error, "kid is unknown" if public_key.blank?

        payload, = JWT.decode(
          token,
          public_key,
          true,
          algorithms: [ALGORITHM],
          required_claims: required,
          leeway: LEEWAY,
          verify_iat: true,
          verify_exp: true,
          verify_iss: true,
          iss: issuer,
          verify_aud: true,
          aud: audience,
        )
        [payload, header]
      rescue JWT::DecodeError, JWT::VerificationError => e
        raise Error, "token verification failed: #{e.message}"
      end
    end
  end
end
