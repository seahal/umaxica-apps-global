# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"
require "jwt"

class EntraIdTokenVerifierTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  OBJECT_ID = "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb"
  NONCE = "test-nonce-abc123"

  test "returns verified authentication evidence for a valid Entra ID token" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-key-id" })
    jwks_loader = ->(_) { { "keys" => [jwk.export] } }
    now = Time.current.to_i
    token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => CLIENT_ID,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-subject",
        "nonce" => NONCE,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key,
      "RS256",
      { "kid" => "test-key-id" },
    )

    authentication = EntraIdTokenVerifier.call(
      id_token: token,
      expected_nonce: NONCE,
      expected_tenant_id: TENANT_ID,
      client_id: CLIENT_ID,
      jwks_loader: jwks_loader,
    )

    assert_predicate authentication, :verified?
    assert_equal TENANT_ID, authentication.tenant_id
    assert_equal OBJECT_ID, authentication.entra_object_id
    assert_equal "pairwise-subject", authentication.evidence_subject
  end

  test "returns rejected authentication for invalid required inputs" do
    missing_token = EntraIdTokenVerifier.call(
      id_token: "",
      expected_nonce: NONCE,
      expected_tenant_id: TENANT_ID,
      client_id: CLIENT_ID,
    )
    missing_nonce = EntraIdTokenVerifier.call(
      id_token: "token",
      expected_nonce: "",
      expected_tenant_id: TENANT_ID,
      client_id: CLIENT_ID,
    )
    invalid_tenant = EntraIdTokenVerifier.call(
      id_token: "token",
      expected_nonce: NONCE,
      expected_tenant_id: "not-a-uuid",
      client_id: CLIENT_ID,
    )

    assert_equal "missing_id_token", missing_token.error
    assert_equal "missing_nonce", missing_nonce.error
    assert_equal "invalid_tenant_id", invalid_tenant.error
  end

  test "returns rejected authentication when JWKS retrieval fails" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    now = Time.current.to_i
    token = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
        "aud" => CLIENT_ID,
        "tid" => TENANT_ID,
        "oid" => OBJECT_ID,
        "sub" => "pairwise-subject",
        "nonce" => NONCE,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key,
      "RS256",
      { "kid" => "unavailable-key" },
    )
    loader = ->(*) { raise EntraJwksCache::FetchError, "unavailable" }

    authentication = EntraIdTokenVerifier.call(
      id_token: token,
      expected_nonce: NONCE,
      expected_tenant_id: TENANT_ID,
      client_id: CLIENT_ID,
      jwks_loader: loader,
    )

    assert_predicate authentication, :rejected?
    assert_equal "jwks_fetch_failed", authentication.error
  end

  test "returns precise rejection codes for invalid Entra identity claims" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-key-id" })
    jwks_loader = ->(_) { { "keys" => [jwk.export] } }
    now = Time.current.to_i
    valid_claims = {
      "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
      "aud" => CLIENT_ID,
      "tid" => TENANT_ID,
      "oid" => OBJECT_ID,
      "sub" => "pairwise-subject",
      "nonce" => NONCE,
      "iat" => now,
      "exp" => now + 3600,
    }
    cases = {
      "nonce_mismatch" => { "nonce" => "wrong-nonce" },
      "tid_missing" => { "tid" => nil },
      "tid_mismatch" => { "tid" => "22222222-3333-4444-5555-666666666666" },
      "oid_missing" => { "oid" => nil },
      "oid_invalid_format" => { "oid" => "not-a-uuid" },
    }

    cases.each do |expected_error, overrides|
      token = JWT.encode(
        valid_claims.merge(overrides).compact,
        private_key,
        "RS256",
        { "kid" => "test-key-id" },
      )

      authentication = EntraIdTokenVerifier.call(
        id_token: token,
        expected_nonce: NONCE,
        expected_tenant_id: TENANT_ID,
        client_id: CLIENT_ID,
        jwks_loader: jwks_loader,
      )

      assert_predicate authentication, :rejected?
      assert_equal expected_error, authentication.error
    end
  end

  test "returns token decode failure for invalid signature issuer audience and expiry" do
    private_key = OpenSSL::PKey::RSA.generate(2048)
    other_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(private_key, { "kid" => "test-key-id" })
    jwks_loader = ->(_) { { "keys" => [jwk.export] } }
    now = Time.current.to_i
    valid_claims = {
      "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
      "aud" => CLIENT_ID,
      "tid" => TENANT_ID,
      "oid" => OBJECT_ID,
      "sub" => "pairwise-subject",
      "nonce" => NONCE,
      "iat" => now,
      "exp" => now + 3600,
    }
    tokens = [
      JWT.encode(valid_claims, other_key, "RS256", { "kid" => "test-key-id" }),
      JWT.encode(valid_claims.merge("iss" => "https://malicious.example/v2.0"), private_key, "RS256", { "kid" => "test-key-id" }),
      JWT.encode(valid_claims.merge("aud" => "wrong-client"), private_key, "RS256", { "kid" => "test-key-id" }),
      JWT.encode(valid_claims.merge("iat" => now - 7200, "exp" => now - 3600), private_key, "RS256", { "kid" => "test-key-id" }),
    ]

    tokens.each do |token|
      authentication = EntraIdTokenVerifier.call(
        id_token: token,
        expected_nonce: NONCE,
        expected_tenant_id: TENANT_ID,
        client_id: CLIENT_ID,
        jwks_loader: jwks_loader,
      )

      assert_predicate authentication, :rejected?
      assert_equal "token_decode_failed", authentication.error
    end
  end
end
