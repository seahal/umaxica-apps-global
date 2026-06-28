# frozen_string_literal: true

require "test_helper"

class CoreBrowserApiBoundaryTest < ActionDispatch::IntegrationTest
  HOST = ENV.fetch("CORE_SERVICE_URL")

  setup do
    @previous_flag = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
    host! HOST
    https!
  end

  teardown do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = @previous_flag
    Actor.clear if defined?(Actor)
  end

  test "core browser api is disabled by default feature flag" do
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = nil

    get("/api/v0/session", headers: json_headers)

    assert_response :service_unavailable
    body = response.parsed_body

    assert_equal "service_unavailable", body.dig("error", "code")
    assert_predicate body.dig("error", "request_id"), :present?
  ensure
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"
  end

  test "unauthenticated session response returns csrf token and no credentials" do
    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert_not body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_not_includes response.body, CoreBrowserCredentialContract::ACCESS_COOKIE
    assert_not_includes response.body, CoreBrowserCredentialContract::REFRESH_COOKIE
  end

  test "core-browser access token is rejected from authorization header transport" do
    access_token = core_browser_access_token

    get "/api/v0/session", headers: json_headers.merge("Authorization" => "Bearer #{access_token}")

    assert_response :unauthorized
    body = response.parsed_body

    assert_equal "authentication_required", body.dig("error", "code")
    assert_predicate body.dig("error", "request_id"), :present?
  end

  test "palm audience token is rejected from core browser cookie transport" do
    token = core_browser_access_token(audiences: ["palm-api"])
    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] = token

    get "/api/v0/session", headers: json_headers

    assert_response :unauthorized
    body = response.parsed_body

    assert_equal "authentication_required", body.dig("error", "code")
  end

  test "authenticated session response is minimal and excludes raw credentials" do
    cookies[CoreBrowserCredentialContract::ACCESS_COOKIE] = core_browser_access_token

    get "/api/v0/session", headers: json_headers

    assert_response :success
    body = response.parsed_body

    assert body.fetch("authenticated")
    assert_predicate body.fetch("csrf_token"), :present?
    assert_equal clients(:one).public_id, body.dig("actor", "id")
    assert_not body.key?("access_token")
    assert_not body.key?("refresh_token")
    assert_not_includes response.body, cookies[CoreBrowserCredentialContract::ACCESS_COOKIE].to_s
  end

  test "unsafe refresh without csrf returns json csrf error contract" do
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] = client_tokens(:one).rotate_refresh_token!

    post "/api/v0/token/refresh", headers: json_headers

    assert_response :forbidden
    body = response.parsed_body

    assert_equal "csrf_verification_failed", body.dig("error", "code")
    assert_predicate body.dig("error", "request_id"), :present?
    assert_nil body.dig("error", "detail")
  end

  test "refresh rotates opaque cookie and never returns credentials in body" do
    get "/api/v0/session", headers: json_headers
    csrf_token = response.parsed_body.fetch("csrf_token")
    refresh = client_tokens(:one).rotate_refresh_token!
    cookies[CoreBrowserCredentialContract::REFRESH_COOKIE] = refresh

    post "/api/v0/token/refresh", headers: json_headers.merge("X-CSRF-Token" => csrf_token)

    assert_response :success
    body = response.parsed_body

    assert body.fetch("refreshed")
    assert_not body.key?("access_token")
    assert_not body.key?("refresh_token")

    access_cookie = set_cookie_for(CoreBrowserCredentialContract::ACCESS_COOKIE)
    refresh_cookie = set_cookie_for(CoreBrowserCredentialContract::REFRESH_COOKIE)

    assert_includes access_cookie.downcase, "httponly"
    assert_includes access_cookie.downcase, "secure"
    assert_includes access_cookie.downcase, "samesite=strict"
    assert_includes access_cookie, "path=/"
    assert_no_match(/domain=/i, access_cookie)
    assert_includes refresh_cookie.downcase, "httponly"
    assert_includes refresh_cookie.downcase, "secure"
    assert_includes refresh_cookie.downcase, "samesite=strict"
    assert_includes refresh_cookie, "path=/"
    assert_no_match(/domain=/i, refresh_cookie)
  end

  private

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }
  end

  def core_browser_access_token(audiences: [CoreBrowserCredentialContract::ACCESS_AUDIENCE])
    token_record = client_tokens(:one)
    AuthenticationTokenService.encode(
      clients(:one),
      host: HOST,
      resource_type: "client",
      session_public_id: token_record.public_id,
      session_id: token_record.public_id,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile:read self:read),
      issuer: AuthenticationJwtConfiguration.issuer("client"),
      audiences: audiences,
      jwt_issuer_id: CoreBrowserCredentialContract.core_jwt_issuer_id("client"),
    )
  end

  def set_cookie_for(name)
    response_set_cookie_lines.find { |line| line.start_with?("#{name}=") }.to_s
  end
end
