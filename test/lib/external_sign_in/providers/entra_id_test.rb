# typed: false
# frozen_string_literal: true

require "test_helper"
require "openssl"
require "jwt"

class ExternalSignIn::Providers::EntraIdTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  CLIENT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  VALID_OID = "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb"
  NONCE     = "test-nonce-abc123"

  setup do
    @private_key = OpenSSL::PKey::RSA.generate(2048)
    @jwk = JWT::JWK.new(@private_key, { "kid" => "test-key-id" })
    @jwks = { "keys" => [@jwk.export] }
    @jwks_loader = ->(_opts) { @jwks }
  end

  # --- success path ---

  test "returns NormalizedAuthResult for a valid token" do
    token = build_token
    result = call(id_token: token)

    assert_instance_of ExternalSignIn::NormalizedAuthResult, result
    assert_equal TENANT_ID, result.tenant_id
    assert_equal VALID_OID, result.entra_object_id
    assert_equal "https://login.microsoftonline.com/#{TENANT_ID}/v2.0", result.evidence_issuer
    assert_equal "pairwise-sub-value", result.evidence_subject
  end

  test "stores iss as evidence_issuer" do
    result = call(id_token: build_token)

    assert_equal "https://login.microsoftonline.com/#{TENANT_ID}/v2.0", result.evidence_issuer
  end

  test "stores sub as evidence_subject" do
    result = call(id_token: build_token)

    assert_equal "pairwise-sub-value", result.evidence_subject
  end

  # --- nonce validation ---

  test "raises VerificationError when nonce is missing from token" do
    token = build_token("nonce" => nil)

    assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
      call(id_token: token)
    end
  end

  test "raises VerificationError when nonce does not match" do
    token = build_token("nonce" => "wrong-nonce")

    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: token)
      end
    assert_equal "nonce_mismatch", error.reason
  end

  # --- issuer validation ---

  test "raises VerificationError when issuer is wrong" do
    token = build_token("iss" => "https://malicious.example.com/v2.0")

    assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
      call(id_token: token)
    end
  end

  # --- audience validation ---

  test "raises VerificationError when audience is wrong" do
    token = build_token("aud" => "wrong-client-id")

    assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
      call(id_token: token)
    end
  end

  # --- tid claim validation ---

  test "raises VerificationError when tid claim does not match expected_tenant_id" do
    other_tenant = "22222222-3333-4444-5555-666666666666"
    token = build_token("tid" => other_tenant)

    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: token)
      end
    assert_equal "tid_mismatch", error.reason
  end

  test "raises VerificationError when tid claim is missing" do
    token = build_token("tid" => nil)

    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: token)
      end
    assert_equal "tid_missing", error.reason
  end

  # --- oid claim validation ---

  test "raises VerificationError when oid is missing" do
    token = build_token("oid" => nil)

    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: token)
      end
    assert_equal "oid_missing", error.reason
  end

  test "raises VerificationError when oid is not UUID format" do
    token = build_token("oid" => "not-a-uuid")

    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: token)
      end
    assert_equal "oid_invalid_format", error.reason
  end

  # --- input validation ---

  test "raises VerificationError when id_token is blank" do
    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: "")
      end
    assert_equal "missing_id_token", error.reason
  end

  test "raises VerificationError when expected_nonce is blank" do
    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: build_token, expected_nonce: "")
      end
    assert_equal "missing_nonce", error.reason
  end

  test "raises VerificationError when expected_tenant_id is not a UUID" do
    error =
      assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
        call(id_token: build_token, expected_tenant_id: "not-a-uuid")
      end
    assert_equal "invalid_tenant_id", error.reason
  end

  # --- token integrity ---

  test "raises VerificationError for a tampered token" do
    token = build_token
    # Replace the signature segment (everything after the last '.') with wrong bytes.
    # Using a different RSA key so the signature bytes are structurally valid but wrong.
    other_key = OpenSSL::PKey::RSA.generate(2048)
    parts = token.split(".")
    wrong_sig = JWT::Base64.url_encode(other_key.sign(OpenSSL::Digest::SHA256.new, "#{parts[0]}.#{parts[1]}"))
    tampered = "#{parts[0]}.#{parts[1]}.#{wrong_sig}"

    assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
      call(id_token: tampered)
    end
  end

  test "raises VerificationError for an expired token" do
    past = Time.now.to_i - 7200
    token = build_token("iat" => past, "exp" => past + 3600)

    assert_raises(ExternalSignIn::Providers::EntraId::VerificationError) do
      call(id_token: token)
    end
  end

  private

  def build_token(overrides = {})
    now = Time.now.to_i
    payload = {
      "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
      "aud" => CLIENT_ID,
      "tid" => TENANT_ID,
      "oid" => VALID_OID,
      "sub" => "pairwise-sub-value",
      "nonce" => NONCE,
      "iat" => now,
      "exp" => now + 3600,
    }.merge(overrides).compact

    JWT.encode(payload, @private_key, "RS256", { "kid" => "test-key-id" })
  end

  def call(id_token:, expected_nonce: NONCE, expected_tenant_id: TENANT_ID, client_id: CLIENT_ID)
    ExternalSignIn::Providers::EntraId.new(
      id_token: id_token,
      expected_nonce: expected_nonce,
      expected_tenant_id: expected_tenant_id,
      client_id: client_id,
      jwks_loader: @jwks_loader,
    ).call
  end
end
