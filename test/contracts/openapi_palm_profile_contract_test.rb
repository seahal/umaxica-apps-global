# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the Palm bearer-token endpoint against the app surface description.
#
# `/api/v0/profile` exists on the app surface only, which is the case a single shared description
# with one host variable could not express.
class OpenapiPalmProfileContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  openapi_surface :app

  HOST = ENV.fetch("PRIVATE_PALM_SERVICE_URL")

  setup do
    host! HOST
    https!
  end

  test "an authenticated profile conforms" do
    persisted = persisted_palm_token

    get "/api/v0/profile",
        headers: json_headers.merge("Authorization" => "Bearer #{palm_token(sid: persisted.oidc_sid, jti: persisted.oidc_jti)}")

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_openapi_conform 200
  end

  test "a missing bearer token conforms, WWW-Authenticate included" do
    get "/api/v0/profile", headers: json_headers

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
    # The schema declares this header on 401, and Committee validates response headers, so this
    # assertion is enforced by assert_openapi_conform as well as stated here.
    assert_equal %(Bearer error="invalid_token"), response.headers["WWW-Authenticate"]
    assert_openapi_conform 401
  end

  test "an insufficient scope conforms" do
    get "/api/v0/profile",
        headers: json_headers.merge("Authorization" => "Bearer #{palm_token(scopes: %w(openid))}")

    assert_response :forbidden
    assert_equal %(Bearer error="insufficient_scope"), response.headers["WWW-Authenticate"]
    assert_openapi_conform 403
  end

  test "a cookie-bearing request is refused, and the refusal conforms" do
    # An endpoint accepts exactly one credential transport; Palm rejects any request with cookies.
    persisted = persisted_palm_token
    cookies["auth_access"] = "irrelevant"

    get "/api/v0/profile",
        headers: json_headers.merge("Authorization" => "Bearer #{palm_token(sid: persisted.oidc_sid, jti: persisted.oidc_jti)}")

    assert_response :unauthorized
    assert_equal "application/problem+json", response.media_type
    assert_openapi_conform 401
  end

  private

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end

  def palm_token(client: clients(:one), scopes: %w(openid palm.read),
                 audiences: [PalmAccessTokenAuthenticator::AUDIENCE], client_id: "app-ios-rp",
                 sid: SecureRandom.uuid, jti: SecureRandom.uuid)
    AuthenticationTokenService.encode(
      client,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: sid,
      session_id: sid,
      expires_at: 10.minutes.from_now,
      scopes: scopes,
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: audiences,
      subject: OidcSubject.for(client, resource_type: "client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      client_id: client_id,
      oidc_sid: sid,
      oidc_jti: jti,
    )
  end

  def persisted_palm_token(client: clients(:one), client_id: "app-ios-rp")
    ClientToken.create!(
      user: client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      oidc_sid: SecureRandom.uuid,
      oidc_jti: SecureRandom.uuid,
      oidc_client_id: client_id,
    )
  end
end
