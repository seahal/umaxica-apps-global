# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"

class WellKnownJwksControllerTest < ActionDispatch::IntegrationTest
  fixtures_none!

  def self.normalized_host(value)
    value.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end

  ENDPOINTS = [
    ["acme app", "ACME_APP", normalized_host(ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))],
    ["acme com", "ACME_COM", normalized_host(ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))],
    ["acme org", "ACME_ORG", normalized_host(ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))],
    ["core app", "CORE_APP", normalized_host(ENV.fetch("CORE_SERVICE_URL", "core-jp.umaxica.app"))],
    ["core com", "CORE_COM", normalized_host(ENV.fetch("CORE_CORPORATE_URL", "core-jp.umaxica.com"))],
    ["core org", "CORE_ORG", normalized_host(ENV.fetch("CORE_STAFF_URL", "core-jp.umaxica.org"))],
    ["sign app", "SIGN_APP", normalized_host(ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app"))],
    ["sign com", "SIGN_COM", normalized_host(ENV.fetch("SIGN_CORPORATE_URL", "id.umaxica.com"))],
    ["sign org", "SIGN_ORG", normalized_host(ENV.fetch("SIGN_STAFF_URL", "id.umaxica.org"))],
  ].freeze

  setup do
    @jwt_env = docker_core_jwt_env
    @previous_env = @jwt_env.transform_values { |_value| nil }
    @jwt_env.each do |key, value|
      @previous_env[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    JitSecurityJwtRegistry.reload!
  end

  teardown do
    @previous_env.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    JitSecurityJwtRegistry.reload!
  end

  ENDPOINTS.each do |name, namespace, host|
    test "#{name} well-known JWKS returns JSON" do
      host! host

      get "/.well-known/jwks.json", headers: browser_headers

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_nil response.headers["Location"]
      assert_predicate response.headers["Set-Cookie"], :blank?
      assert_match(/max-age=3600/, response.headers["Cache-Control"])
      assert_includes response.parsed_body.keys, "keys"
      key = response.parsed_body.fetch("keys").first

      assert_equal JitSecurityJwtRegistry.surface(namespace).current_kid, key.fetch("kid")
      assert_equal "EC", key.fetch("kty")
      assert_equal "P-384", key.fetch("crv")
      assert_equal "ES384", key.fetch("alg")
      assert_equal "sig", key.fetch("use")
      assert_not_equal "none", key.fetch("alg")
      assert_not_includes key.keys, "d"
      assert_not_includes key.keys, "k"
      assert_not_includes key.keys, "pem"
    end
  end

  def docker_core_jwt_env
    key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    ENDPOINTS.each_with_object({}) do |(_name, namespace, _host), env|
      env["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      env["JWT_#{namespace}_PRIVATE_KEY"] = key
      env["JWT_#{namespace}_PUBLIC_KEYSET"] = nil
    end
  end
end
