# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::JwksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "returns JWKS as JSON" do
    get sign_app_jwks_url(host: @host, ri: "jp"), headers: browser_headers

    assert_response :ok
    body = response.parsed_body

    assert body.key?("keys")
    assert_kind_of Array, body["keys"]
  end

  test "sets cache headers for 1 hour" do
    get sign_app_jwks_url(host: @host, ri: "jp"), headers: browser_headers

    assert_response :ok
    assert_match(/max-age=3600/, response.headers["Cache-Control"])
  end

  test "JWKS keys have required fields when configured" do
    get sign_app_jwks_url(host: @host, ri: "jp"), headers: browser_headers

    assert_response :ok
    body = response.parsed_body

    return if body["keys"].empty?

    key = body["keys"].first

    assert_predicate key["kty"], :present?, "JWK should have kty"
    assert_predicate key["kid"], :present?, "JWK should have kid"
    assert_equal "sig", key["use"]
    assert_equal "ES384", key["alg"]
  end

  test "accessible without authentication" do
    get sign_app_jwks_url(host: @host, ri: "jp"), headers: browser_headers

    assert_response :ok
  end
end
