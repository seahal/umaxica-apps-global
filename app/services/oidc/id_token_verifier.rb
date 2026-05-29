# typed: false
# frozen_string_literal: true

module Oidc
  class IdTokenVerifier < ApplicationService
    Result =
      Data.define(:success, :payload, :error) do
        def success? = success
      end

    def initialize(id_token:, client_id:, resource_type:, expected_nonce:, jwt_issuer_id: nil, issuer: nil)
      super()
      @id_token = id_token
      @client_id = client_id
      @resource_type = resource_type
      @expected_nonce = expected_nonce
      @jwt_issuer_id = jwt_issuer_id
      @issuer = issuer
    end

    def call
      return failure("missing_id_token") if id_token.blank?
      return failure("missing_nonce") if expected_nonce.blank?

      payload = decode!
      return failure("nonce_mismatch") unless secure_equal?(payload["nonce"], expected_nonce)

      Result.new(success: true, payload: payload, error: nil)
    rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError, ArgumentError, TypeError
      failure("invalid_id_token")
    end

    private

    attr_reader :id_token, :client_id, :resource_type, :expected_nonce, :jwt_issuer_id, :issuer

    def decode!
      header = Jit::Security::Jwt::Keyring.parse_header(id_token)
      raise JWT::DecodeError, "invalid header" unless header["alg"] == Authentication::TokenService::JWT_ALGORITHM
      raise JWT::DecodeError, "invalid typ" unless header["typ"] == Oidc::IdTokenIssuer::TOKEN_TYPE

      public_key = Jit::Security::Jwt::Keyring.public_key_for(
        header["kid"],
        issuer_id: resolved_jwt_issuer_id,
      )
      raise JWT::DecodeError, "unknown kid" unless public_key

      payload, = JWT.decode(
        id_token,
        public_key,
        true,
        algorithms: [Authentication::TokenService::JWT_ALGORITHM],
        required_claims: %w(iss aud exp iat sub nonce jti typ act),
        leeway: Authentication::Base::JwtConfiguration.leeway_seconds,
        verify_iat: true,
        verify_exp: true,
        verify_iss: true,
        iss: issuer.presence || Oidc::Issuer.for_resource_type(resource_type),
        verify_aud: true,
        aud: client_id,
      )
      raise JWT::DecodeError, "invalid payload typ" unless payload["typ"] == Oidc::IdTokenIssuer::TOKEN_TYPE
      raise JWT::DecodeError, "invalid act" unless payload["act"] == resource_type

      payload
    end

    def secure_equal?(actual, expected)
      actual = actual.to_s
      expected = expected.to_s
      return false if actual.bytesize != expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
    end

    def failure(error)
      Result.new(success: false, payload: nil, error: error)
    end

    def resolved_jwt_issuer_id
      jwt_issuer_id.presence || Oidc::Issuer.jwt_issuer_id_for_resource_type(resource_type)
    end
  end
end
