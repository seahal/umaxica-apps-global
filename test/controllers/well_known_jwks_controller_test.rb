# typed: false
# frozen_string_literal: true

require "test_helper"

class WellKnownJwksControllerTest < ActionDispatch::IntegrationTest
  fixtures_none!

  def self.normalized_host(value)
    value.to_s.strip.sub(/\Ahttps?:\/\//, "").split("/").first
  end

  ENDPOINTS = [
    ["acme app", "ACME_APP", normalized_host(ENV.fetch("ACME_SERVICE_URL", "app.localhost"))],
    ["acme com", "ACME_COM", normalized_host(ENV.fetch("ACME_CORPORATE_URL", "com.localhost"))],
    ["acme org", "ACME_ORG", normalized_host(ENV.fetch("ACME_STAFF_URL", "org.localhost"))],
    ["core app", "CORE_APP", normalized_host(ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"))],
    ["core com", "CORE_COM", normalized_host(ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"))],
    ["core org", "CORE_ORG", normalized_host(ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"))],
    ["sign app", "SIGN_APP", normalized_host(ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app"))],
    ["sign com", "SIGN_COM", normalized_host(ENV.fetch("SIGN_CORPORATE_URL", "id.umaxica.com"))],
    ["sign org", "SIGN_ORG", normalized_host(ENV.fetch("SIGN_STAFF_URL", "id.umaxica.org"))],
  ].freeze

  setup do
    @jwt_env = docker_core_jwt_env
    @previous_env = @jwt_env.transform_values { |_value| nil }
    @jwt_env.each do |key, value|
      @previous_env[key] = ENV[key]
      ENV[key] = value
    end
  end

  teardown do
    @previous_env.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
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

      assert_equal Jit::Security::Jwt::Registry.surface(namespace).current_kid, key.fetch("kid")
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
    Rails.root.join("docker/core/env").read.lines.filter_map do |line|
      next unless line.start_with?("JWT_")

      line.chomp.split("=", 2)
    end.to_h
  end
end
