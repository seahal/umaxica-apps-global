# typed: false
# frozen_string_literal: true

require "test_helper"
require "json"

class Oidc::JwksServiceTest < ActiveSupport::TestCase
  fixtures_none!

  test "jwk_set returns a hash with keys array" do
    result = Oidc::JwksService.jwk_set

    assert_kind_of Hash, result
    assert result.key?(:keys)
    assert_kind_of Array, result[:keys]
  end

  test "jwk_set keys have required JWK fields when key is configured" do
    result = Oidc::JwksService.jwk_set

    # If no key is configured, keys array may be empty
    return if result[:keys].empty?

    key = result[:keys].first

    assert_predicate key["kty"], :present?, "JWK should have kty"
    assert_predicate key["kid"], :present?, "JWK should have kid"
    assert_equal "sig", key["use"], "JWK use should be sig"
    assert_equal "ES384", key["alg"], "JWK alg should be ES384"
  end

  test "jwk_set delegates to the prebuilt jwt jwks document" do
    expected = { keys: [] }

    Jit::Security::Jwt::JwksService.stub(:jwk_set, expected) do
      result = Oidc::JwksService.jwk_set

      assert_same expected, result
    end
  end

  test "normalizes complete public jwk entries" do
    result = Jit::Security::Jwt::JwksService.normalized_public_jwk(public_jwk)

    assert_equal public_jwk.stringify_keys, result
  end

  test "normalization excludes private jwk material" do
    jwk = {
      kty: "EC",
      crv: "P-384",
      kid: "sign-app-es384-test-a",
      alg: "ES384",
      use: "sig",
      x: "x-value",
      y: "y-value",
      d: "private-value",
    }

    assert_nil Jit::Security::Jwt::JwksService.normalized_public_jwk(jwk)
  end

  test "normalization rejects alg none" do
    jwk = public_jwk.merge(alg: "none")

    assert_nil Jit::Security::Jwt::JwksService.normalized_public_jwk(jwk)
  end

  test "normalization rejects non ES384 algorithms" do
    jwk = public_jwk.merge(alg: "ES256")

    assert_nil Jit::Security::Jwt::JwksService.normalized_public_jwk(jwk)
  end

  test "normalization rejects non signing use" do
    jwk = public_jwk.merge(use: "enc")

    assert_nil Jit::Security::Jwt::JwksService.normalized_public_jwk(jwk)
  end

  test "normalization rejects incomplete jwk entries" do
    jwk = public_jwk.except(:y)

    assert_nil Jit::Security::Jwt::JwksService.normalized_public_jwk(jwk)
  end

  test "surface jwk_set returns prebuilt current public key material" do
    result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")
    key = result.fetch(:keys).first

    assert_predicate key.fetch("kid"), :present?
    assert_equal "EC", key.fetch("kty")
    assert_equal "P-384", key.fetch("crv")
    assert_equal "ES384", key.fetch("alg")
    assert_equal "sig", key.fetch("use")
    assert_not_includes key.keys, "d"
  end

  private

  def public_jwk
    {
      kty: "EC",
      crv: "P-384",
      kid: Jit::Security::Jwt::Registry.surface("SIGN_APP").current_kid,
      alg: "ES384",
      use: "sig",
      x: "x-value",
      y: "y-value",
    }
  end
end
