# typed: false
# frozen_string_literal: true

module Identity
  module SecretCredentialCeremony
    class Result
      TOKEN_TYPE = "secret-credential-ceremony-result+jwt"
      PURPOSE = "secret_credential_ceremony_result"
      PROOF_METHOD = "secret_credential"

      REQUIRED_CLAIMS = %w(
        typ iss aud purpose surface actor_ref session_ref transaction_id grant_jti result_jti operation proof_method
        verified_at challenge_id expires_at iat exp credential_candidate_ref credential_candidate_digest
      ).freeze
      OPTIONAL_CLAIMS = %w(name).freeze
      ALLOWED_CLAIMS = (REQUIRED_CLAIMS + OPTIONAL_CLAIMS).freeze

      attr_reader :payload, :kid

      def initialize(payload, kid: nil, now: Time.current)
        @payload = payload.stringify_keys
        validate!(now: now)
        @kid = kid
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
        Contract.validate_exact!(payload, "proof_method", PROOF_METHOD)
        Contract.validate_timestamp!(payload, "verified_at")
        raise Error, "verified_at must not be in the future" if payload["verified_at"].to_i > now.to_i + Contract::LEEWAY
      end

      def self.default_claims(attributes, now:)
        surface = attributes.fetch(:surface, attributes["surface"]).to_s
        {
          "typ" => TOKEN_TYPE,
          "iss" => Contract.sign_issuer(surface),
          "aud" => Contract.acme_audience(surface),
          "purpose" => PURPOSE,
          "proof_method" => PROOF_METHOD,
          "iat" => now.to_i,
          "exp" => attributes.fetch(:expires_at, attributes["expires_at"]),
        }
      end
    end
  end
end
