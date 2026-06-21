# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/auth_helpers"

class Acme::Org::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  fixtures_none!

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @client = OidcClientRegistry.find!("sign-rp")
    @operator = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
    )
    @session_public_id = @token.public_id
    set_access_cookie(acme_access_token(@operator, resource_type: "operator", jwt_issuer_id: "surface:ACME_ORG"))
  end

  test "routes get and post to oidc logout without changing helper" do
    get_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    post_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :post)

    assert_equal "acme/org/oidc/logouts", get_route[:controller]
    assert_equal "show", get_route[:action]
    assert_equal "acme/org/oidc/logouts", post_route[:controller]
    assert_equal "create", post_route[:action]
    assert_equal "/oidc/logout", acme_org_oidc_logout_path
  end

  test "get without params renders confirmation without mutation" do
    get acme_org_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "validated logout request is staged through shared confirmation" do
    redirect_uri =
      @client.post_logout_redirect_uris.find do |uri|
        URI.parse(uri).host == ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")
      end

    get acme_org_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
        headers: session_headers

    assert_response :see_other
    assert_equal "/sign/out/edit", URI.parse(response.location).path

    follow_redirect!

    assert_response :ok

    post acme_org_oidc_logout_url(host: @host), headers: session_headers

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal URI.parse(redirect_uri).host, location.host
    assert_equal URI.parse(redirect_uri).path, location.path
    assert_equal "xyz", query["state"]
  end

  test "invalid post_logout_redirect_uri never redirects externally" do
    post acme_org_oidc_logout_url(host: @host),
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
      "X-TEST-CURRENT-STAFF" => @operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @session_public_id,
    )
  end

  def acme_access_token(resource, resource_type:, jwt_issuer_id:)
    AuthenticationToken.encode(
      resource,
      host: @host,
      session_public_id: @session_public_id,
      resource_type: resource_type,
      jwt_issuer_id: jwt_issuer_id,
    )
  end

  def id_token(resource: @operator, subject: OidcSubject.for(@operator, resource_type: "operator"),
               sid: @session_public_id)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: @client,
      nonce: "nonce",
      issuer: OidcIssuer.for_resource_type("operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
      subject: subject,
      sid: sid,
    )
  end
end
