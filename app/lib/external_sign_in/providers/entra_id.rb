# typed: false
# frozen_string_literal: true

require "jwt"

module ExternalSignIn
  module Providers
    # Verifies a Microsoft Entra ID OIDC ID token and returns a NormalizedAuthResult.
    #
    # Raises VerificationError if the token is invalid, expired, has a nonce mismatch,
    # wrong issuer/audience, or contains a non-UUID tid/oid.
    #
    # Keys are resolved via EntraJwksCache (JWKS, RS256 only).
    # Lookup key used downstream: NormalizedAuthResult#tenant_id + #object_id (tid + oid).
    # Evidence fields (iss, sub) are captured for audit; never used for auth lookup.
    class EntraId
      class VerificationError < StandardError
        attr_reader :reason

        def initialize(reason)
          super(reason)
          @reason = reason
        end
      end

      ISSUER_TEMPLATE = "https://login.microsoftonline.com/%s/v2.0"
      ALLOWED_ALGORITHMS = ["RS256"].freeze
      UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      private_constant :UUID_FORMAT

      # jwks_loader: injectable for testing; defaults to EntraJwksCache#loader in production.
      def initialize(id_token:, expected_nonce:, expected_tenant_id:, client_id:, jwks_loader: nil)
        @id_token = id_token
        @expected_nonce = expected_nonce
        @expected_tenant_id = expected_tenant_id
        @client_id = client_id
        @jwks_loader = jwks_loader
      end

      def call
        fail!("missing_id_token") if id_token.blank?
        fail!("missing_nonce") if expected_nonce.blank?
        fail!("invalid_tenant_id") unless valid_uuid?(expected_tenant_id)

        payload = decode_token
        verify_nonce!(payload)
        verify_tid!(payload)
        verify_oid!(payload)

        NormalizedAuthResult.new(
          tenant_id: payload["tid"],
          entra_object_id: payload["oid"],
          evidence_issuer: payload["iss"],
          evidence_subject: payload["sub"],
        )
      rescue VerificationError
        raise
      rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError,
             ArgumentError, TypeError, KeyError
        raise VerificationError.new("token_decode_failed")
      rescue Net::OpenTimeout, SocketError, SystemCallError, StandardError
        raise VerificationError.new("jwks_fetch_failed")
      end

      private

      attr_reader :id_token, :expected_nonce, :expected_tenant_id, :client_id

      def decode_token
        loader = @jwks_loader || EntraJwksCache.new(tenant_id: expected_tenant_id).loader
        payload, _header = JWT.decode(
          id_token,
          nil,
          true,
          algorithms: ALLOWED_ALGORITHMS,
          jwks: loader,
          iss: expected_issuer,
          verify_iss: true,
          aud: client_id,
          verify_aud: true,
        )
        payload
      end

      def verify_nonce!(payload)
        nonce = payload["nonce"].to_s
        fail!("nonce_mismatch") unless secure_equal?(nonce, expected_nonce)
      end

      def verify_tid!(payload)
        tid = payload["tid"].to_s
        fail!("tid_missing") if tid.blank?
        fail!("tid_mismatch") unless secure_equal?(tid, expected_tenant_id)
      end

      def verify_oid!(payload)
        oid = payload["oid"].to_s
        fail!("oid_missing") if oid.blank?
        fail!("oid_invalid_format") unless valid_uuid?(oid)
      end

      def expected_issuer
        format(ISSUER_TEMPLATE, expected_tenant_id)
      end

      def secure_equal?(a, b)
        a = a.to_s
        b = b.to_s
        return false if a.bytesize != b.bytesize

        ActiveSupport::SecurityUtils.secure_compare(a, b)
      end

      def valid_uuid?(value)
        value.to_s.match?(UUID_FORMAT)
      end

      def fail!(reason)
        raise VerificationError.new(reason)
      end
    end
  end
end
