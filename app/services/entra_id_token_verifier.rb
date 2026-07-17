# typed: false
# frozen_string_literal: true

require "jwt"

class EntraIdTokenVerifier < ApplicationService
  ISSUER_TEMPLATE = "https://login.microsoftonline.com/%s/v2.0"
  ALLOWED_ALGORITHMS = ["RS256"].freeze
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  private_constant :UUID_FORMAT

  def initialize(id_token:, expected_nonce:, expected_tenant_id:, client_id:, jwks_loader: nil)
    super()
    @id_token = id_token
    @expected_nonce = expected_nonce
    @expected_tenant_id = expected_tenant_id
    @client_id = client_id
    @jwks_loader = jwks_loader
  end

  def call
    return rejected("missing_id_token") if id_token.blank?
    return rejected("missing_nonce") if expected_nonce.blank?
    return rejected("invalid_tenant_id") unless valid_uuid?(expected_tenant_id)

    payload = decode_token
    return rejected("nonce_mismatch") unless secure_equal?(payload["nonce"], expected_nonce)
    return rejected("tid_missing") if payload["tid"].to_s.blank?
    return rejected("tid_mismatch") unless secure_equal?(payload["tid"], expected_tenant_id)
    return rejected("oid_missing") if payload["oid"].to_s.blank?
    return rejected("oid_invalid_format") unless valid_uuid?(payload["oid"])

    EntraAuthenticationResult.verified(
      tenant_id: payload["tid"],
      entra_object_id: payload["oid"],
      evidence_issuer: payload["iss"],
      evidence_subject: payload["sub"],
    )
  rescue EntraJwksCache::FetchError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError
    rejected("jwks_fetch_failed")
  rescue JWT::DecodeError, JWT::VerificationError, OpenSSL::PKey::PKeyError,
         ArgumentError, TypeError, KeyError
    rejected("token_decode_failed")
  end

  private

  attr_reader :id_token, :expected_nonce, :expected_tenant_id, :client_id

  def decode_token
    JWT.decode(
      id_token,
      nil,
      true,
      algorithms: ALLOWED_ALGORITHMS,
      jwks: @jwks_loader || EntraJwksCache.new(tenant_id: expected_tenant_id),
      iss: format(ISSUER_TEMPLATE, expected_tenant_id),
      verify_iss: true,
      aud: client_id,
      verify_aud: true,
    ).first
  end

  def secure_equal?(actual, expected)
    actual = actual.to_s
    expected = expected.to_s
    return false if actual.bytesize != expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def valid_uuid?(value)
    value.to_s.match?(UUID_FORMAT)
  end

  def rejected(error)
    EntraAuthenticationResult.rejected(error: error)
  end
end
