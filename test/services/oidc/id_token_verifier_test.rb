# frozen_string_literal: true

require "test_helper"

class OidcIdTokenVerifierTest < ActiveSupport::TestCase
  setup do
    @client = OidcClientRegistry.find!("core_app")
    @user = clients(:one)
    @nonce = "nonce-#{SecureRandom.hex(4)}"
    @issuer = OidcIssuer.for_client(@client)
    @jwt_issuer_id = OidcIssuer.jwt_issuer_id_for_client(@client)
  end

  test "accepts a valid id token for the expected client issuer actor and nonce" do
    result = verify(id_token)

    assert_predicate result, :success?
    assert_equal @issuer, result.payload.fetch("iss")
    assert_equal @client.client_id, result.payload.fetch("aud")
    assert_equal "client", result.payload.fetch("act")
    assert_equal @nonce, result.payload.fetch("nonce")
  end

  test "rejects wrong issuer audience nonce and actor type" do
    assert_invalid id_token(issuer: "https://evil.example")

    assert_invalid token_with_claims("aud" => "core_org")

    nonce_mismatch = verify(id_token, expected_nonce: "wrong-nonce")

    assert_not nonce_mismatch.success?
    assert_equal "nonce_mismatch", nonce_mismatch.error

    assert_invalid token_with_claims("act" => "operator")
  end

  test "rejects expired tokens and unknown key ids" do
    assert_invalid id_token(expires_at: 1.minute.ago)

    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    forged = JWT.encode(valid_claims, private_key, "ES384", { typ: OidcIdTokenIssuer::TOKEN_TYPE, kid: "unknown" })

    assert_invalid forged
  end

  test "rejects non id-token typ and unsupported algorithms" do
    assert_invalid token_with_claims("typ" => "access-token+jwt")

    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    forged = JWT.encode(valid_claims, private_key, "ES256", { typ: OidcIdTokenIssuer::TOKEN_TYPE, kid: "kid" })

    assert_invalid forged
  end

  private

  def id_token(issuer: @issuer, expires_at: 5.minutes.from_now)
    OidcIdTokenIssuer.call(
      resource: @user,
      client: @client,
      nonce: @nonce,
      issuer: issuer,
      expires_at: expires_at,
      jwt_issuer_id: @jwt_issuer_id,
    )
  end

  def token_with_claims(overrides)
    JitSecurityJwtKeyring.encode(valid_claims.merge(overrides), issuer_id: @jwt_issuer_id)
  end

  def valid_claims
    now = Time.current.to_i
    {
      "iss" => @issuer,
      "sub" => OidcSubject.for(@user, resource_type: "client"),
      "aud" => @client.client_id,
      "exp" => 5.minutes.from_now.to_i,
      "iat" => now,
      "jti" => SecureRandom.uuid,
      "typ" => OidcIdTokenIssuer::TOKEN_TYPE,
      "act" => "client",
      "sid" => SecureRandom.urlsafe_base64(18),
      "nonce" => @nonce,
      "acr" => "aal1",
    }
  end

  def verify(token, expected_nonce: @nonce)
    OidcIdTokenVerifier.call(
      id_token: token,
      client_id: @client.client_id,
      resource_type: "client",
      expected_nonce: expected_nonce,
      issuer: @issuer,
      jwt_issuer_id: @jwt_issuer_id,
    )
  end

  def assert_invalid(token)
    result = verify(token)

    assert_not result.success?
    assert_equal "invalid_id_token", result.error
  end
end
