# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "helpers/auth_helpers"

class Base::App::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @client = OidcClientRegistry.find!("sign-rp")
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @session_public_id = @token.public_id
    set_access_cookie(base_access_token(@user, resource_type: "client", jwt_issuer_id: "surface:BASE_APP"))
  end

  test "routes get and post to oidc logout without changing helper" do
    get_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    post_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :post)

    assert_equal "base/app/oidc/logouts", get_route[:controller]
    assert_equal "show", get_route[:action]
    assert_equal "base/app/oidc/logouts", post_route[:controller]
    assert_equal "create", post_route[:action]
    assert_equal "/oidc/logout", base_app_oidc_logout_path
  end

  test "get without params renders confirmation without mutation" do
    get base_app_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "validated logout request is staged through shared confirmation" do
    redirect_uri = @client.post_logout_redirect_uris.first

    get base_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
        headers: session_headers

    assert_response :see_other
    assert_equal "/sign/out/edit", URI.parse(jump_rt_url_from_location(response.location)).path

    follow_redirect!

    assert_response :ok

    post base_app_oidc_logout_url(host: @host), headers: session_headers

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    location = URI.parse(jump_rt_url_from_location(response.location))
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal URI.parse(redirect_uri).host, location.host
    assert_equal URI.parse(redirect_uri).path, location.path
    assert_equal "xyz", query["state"]
  end

  test "invalid post_logout_redirect_uri never redirects externally" do
    post base_app_oidc_logout_url(host: @host),
         params: {
           id_token_hint: id_token,
           post_logout_redirect_uri: "https://attacker.example/signed-out",
           state: "xyz",
           ri: "jp",
         },
         headers: session_headers

    assert_response :success
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  private

  def session_headers
    browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @session_public_id,
    )
  end

  def base_access_token(resource, resource_type:, jwt_issuer_id:)
    AuthenticationToken.encode(
      resource,
      host: @host,
      session_public_id: @session_public_id,
      resource_type: resource_type,
      jwt_issuer_id: jwt_issuer_id,
    )
  end

  def id_token(resource: @user, subject: OidcSubject.for(@user, resource_type: "client"),
               sid: @session_public_id)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: @client,
      nonce: "nonce",
      issuer: OidcIssuer.for_resource_type("client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      subject: subject,
      sid: sid,
    )
  end
end
