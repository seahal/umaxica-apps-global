# typed: false
# frozen_string_literal: true

require "test_helper"
require "json"

class Oidc::JwksServiceTest < ActiveSupport::TestCase
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

    assert_predicate key[:kty], :present?, "JWK should have kty"
    assert_predicate key[:kid], :present?, "JWK should have kid"
    assert_equal "sig", key[:use], "JWK use should be sig"
    assert_equal "ES384", key[:alg], "JWK alg should be ES384"
  end

  test "jwk_set returns empty keys when no public key configured" do
    Jit::Security::Jwt::Keyring.stub(:public_key_for, nil) do
      result = Oidc::JwksService.jwk_set

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set reads public keyset env" do
    jwk = {
      kty: "EC",
      crv: "P-384",
      kid: "sign-app-es384-test-a",
      alg: "ES384",
      use: "sig",
      x: "x-value",
      y: "y-value",
    }

    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([jwk])) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [jwk.stringify_keys] }, result)
    end
  end

  test "surface jwk_set excludes private jwk material" do
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

    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([jwk])) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set rejects alg none" do
    jwk = public_jwk.merge(alg: "none")

    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([jwk])) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set rejects non ES384 algorithms" do
    jwk = public_jwk.merge(alg: "ES256")

    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([jwk])) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set rejects non signing use" do
    jwk = public_jwk.merge(use: "enc")

    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([jwk])) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set rejects incomplete jwk entries" do
    jwk = public_jwk.except(:y)

    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate([jwk])) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set rejects malformed public keyset json" do
    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => "not-json") do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  test "surface jwk_set rejects non-array public keyset json" do
    with_env("JWT_SIGN_APP_PUBLIC_KEYSET" => JSON.generate(public_jwk)) do
      result = Jit::Security::Jwt::JwksService.jwk_set("SIGN_APP")

      assert_equal({ keys: [] }, result)
    end
  end

  private

  def public_jwk
    {
      kty: "EC",
      crv: "P-384",
      kid: "sign-app-es384-test-a",
      alg: "ES384",
      use: "sig",
      x: "x-value",
      y: "y-value",
    }
  end

  def with_env(vars)
    previous = vars.transform_values { |_value| nil }
    vars.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
