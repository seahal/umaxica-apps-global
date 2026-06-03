# typed: false
# frozen_string_literal: true

module Identity
  module StepUpCeremony
    class Result
      TOKEN_TYPE = "step-up-ceremony-result+jwt"
      PURPOSE = "step_up_ceremony_result"

      REQUIRED_CLAIMS = %w(
        typ iss aud purpose surface actor_ref session_ref transaction_id grant_jti result_jti scope aal method
        verified_at challenge_id expires_at iat exp
      ).freeze
      OPTIONAL_CLAIMS = %w(attempt_count).freeze
      ALLOWED_CLAIMS = (REQUIRED_CLAIMS + OPTIONAL_CLAIMS).freeze

      attr_reader :payload, :kid

      def initialize(payload, kid: nil, now: Time.current)
        @payload = payload.stringify_keys
        @kid = kid
        validate!(now: now)
      end

      def self.issue(attributes, issuer_id:, now: Time.current)
        result = new(attributes.merge(default_claims(attributes, now: now)), now: now)
        Jit::Security::Jwt::Keyring.encode(result.payload, issuer_id: issuer_id)
      end

      def self.decode(token, issuer_id:, now: Time.current)
        unverified = Contract.decode_unverified_payload(token)
        surface = unverified["surface"].to_s
        payload, header = Contract.decode_verified_payload(
          token: token,
          issuer_id: issuer_id,
          issuer: Contract.sign_issuer(surface),
          audience: Contract.acme_audience(surface),
          expected_type: TOKEN_TYPE,
          required: REQUIRED_CLAIMS,
        )
        new(payload, kid: header["kid"], now: now)
      end

      def [](key) = payload[key.to_s]

      def validate!(now: Time.current)
        Contract.validate_common_payload!(
          payload,
          required: REQUIRED_CLAIMS,
          allowed: ALLOWED_CLAIMS,
          purpose: PURPOSE,
          audience: Contract.acme_audience(payload["surface"]),
          issuer: Contract.sign_issuer(payload["surface"]),
          now: now,
        )
        Contract.validate_inclusion!(payload, "method", Contract::METHODS)
      end

      def self.default_claims(attributes, now:)
        surface = attributes.fetch(:surface, attributes["surface"]).to_s
        {
          "typ" => TOKEN_TYPE,
          "iss" => Contract.sign_issuer(surface),
          "aud" => Contract.acme_audience(surface),
          "purpose" => PURPOSE,
          "iat" => now.to_i,
          "exp" => attributes["expires_at"] || attributes[:expires_at],
        }
      end
    end
  end
end
