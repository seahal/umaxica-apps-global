# typed: false
# frozen_string_literal: true

require "test_helper"

module Oidc
  # Regression coverage for the DPoP sender-constraint gate on the UserInfo
  # authenticator. A DPoP-bound access token (one carrying cnf.jkt) must never
  # be accepted as a plain Bearer token, mirroring
  # AuthenticationCurrentResourceResolver#dpop_valid?.
  class AccessTokenAuthenticatorDpopTest < ActiveSupport::TestCase
    def build_authenticator(scheme:, dpop_proof: nil, uri: "http://example.com/userinfo", method: "GET")
      OidcAccessTokenAuthenticator.new(
        access_token: "access-token",
        resource_type: "client",
        host: "example.com",
        authorization_scheme: scheme,
        dpop_proof: dpop_proof,
        request_method: method,
        request_uri: uri,
      )
    end

    def generate_proof_jwk
      ec = OpenSSL::PKey::EC.generate("prime256v1")
      jwk = JWT::JWK.new(ec)
      [ec, jwk.export]
    end

    def build_proof(private_key, jwk, method:, uri:, access_token: nil)
      payload = { "htm" => method, "htu" => uri, "iat" => Time.current.to_i, "jti" => SecureRandom.uuid }
      payload["ath"] = JitSecurityJwtThumbprintCalculator.ath(access_token) if access_token
      JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
    end

    test "rejects a DPoP-bound access token presented as Bearer" do
      auth = build_authenticator(scheme: "Bearer")
      payload = { "cnf" => { "jkt" => "abc" } }

      assert_not auth.send(:dpop_valid?, payload),
                 "a sender-constrained token must not be accepted over Bearer"
    end

    test "rejects a DPoP-bound access token presented with DPoP scheme but no proof" do
      auth = build_authenticator(scheme: "DPoP", dpop_proof: nil)
      payload = { "cnf" => { "jkt" => "abc" } }

      assert_not auth.send(:dpop_valid?, payload)
    end

    test "accepts a standard Bearer token that is not DPoP-bound" do
      auth = build_authenticator(scheme: "Bearer")
      payload = { "sub" => "user-1" }

      assert auth.send(:dpop_valid?, payload)
    end

    test "rejects an unbound token presented with DPoP scheme" do
      auth = build_authenticator(scheme: "DPoP")
      payload = { "sub" => "user-1" }

      assert_not auth.send(:dpop_valid?, payload)
    end

    test "accepts a DPoP-bound token with a valid matching proof" do
      private_key, jwk = generate_proof_jwk
      uri = "http://example.com/userinfo"
      proof = build_proof(private_key, jwk, method: "GET", uri: uri, access_token: "access-token")
      jkt = JitSecurityJwtThumbprintCalculator.calculate(jwk)
      payload = { "sub" => "user-1", "cnf" => { "jkt" => jkt } }

      auth = build_authenticator(scheme: "DPoP", dpop_proof: proof, uri: uri, method: "GET")

      assert auth.send(:dpop_valid?, payload),
             "a valid DPoP proof bound to the token's jkt must be accepted"
    end
  end
end
