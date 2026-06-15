# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/auth_helpers"

class Acme::Org::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @client = OidcClientRegistry.find!("sign-rp")
    @operator = operators(:one)
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

  test "post without params does not silently logout" do
    post acme_org_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "valid id_token_hint on get renders confirmation without mutation" do
    get acme_org_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, ri: "jp" },
        headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  # HEAD shares the GET route in Rails; it must not trigger logout side effects even with a valid hint.
  test "valid id_token_hint on head does not mutate session" do
    assert_no_enqueued_jobs only: OidcBackchannelLogoutDeliveryJob do
      head acme_org_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, ri: "jp" },
           headers: session_headers
    end

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "valid id_token_hint on post logs out and renders front-channel completion" do
    assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
      post acme_org_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, ri: "jp" },
           headers: session_headers
    end

    assert_response :ok
    assert_predicate @token.reload, :revoked?
    assert_includes response.body, "/oidc/frontchannel_logout"
    assert_nil response.location
  end

  test "invalid id_token_hint signature does not mutate or redirect externally" do
    post acme_org_oidc_logout_url(host: @host),
         params: { id_token_hint: "#{id_token}x", ri: "jp" },
         headers: session_headers

    assert_response :bad_request
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "mismatched subject does not mutate or redirect externally" do
    other = operators(:two)
    bad_hint = id_token(resource: other, subject: OidcSubject.for(other, resource_type: "operator"))

    post acme_org_oidc_logout_url(host: @host),
         params: { id_token_hint: bad_hint, ri: "jp" },
         headers: session_headers

    assert_response :bad_request
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "registered post_logout_redirect_uri receives state after logout" do
    redirect_uri =
      @client.post_logout_redirect_uris.find { |uri|
        URI.parse(uri).host == ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")
      }

    assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
      post acme_org_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
           headers: session_headers
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
    assert_equal "xyz", Rack::Utils.parse_nested_query(URI.parse(response.location).query.to_s)["state"]
    assert_not_includes response.body, "/oidc/frontchannel_logout"
  end

  test "unregistered post_logout_redirect_uri never redirects or leaks state" do
    post acme_org_oidc_logout_url(host: @host),
         params: {
           id_token_hint: id_token,
           post_logout_redirect_uri: "https://attacker.example/signed-out",
           state: "xyz",
           ri: "jp",
         },
         headers: session_headers

    assert_response :bad_request
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
    assert_not_includes response.body, "xyz"
  end

  test "legacy logout_request get renders confirmation and post consumes once" do
    OidcLogoutRequest.replay_store = ActiveSupport::Cache::MemoryStore.new
    logout_request = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    get(
      acme_org_oidc_logout_url(host: @host),
      params: { logout_request: logout_request, client_id: "base-rails-rp", ri: "jp" },
      headers: session_headers,
    )

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?

    post(
      acme_org_oidc_logout_url(host: @host),
      params: { logout_request: logout_request, client_id: "base-rails-rp", ri: "jp" },
      headers: session_headers,
    )

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    post(
      acme_org_oidc_logout_url(host: @host),
      params: { logout_request: logout_request, client_id: "base-rails-rp", ri: "jp" },
      headers: session_headers,
    )

    assert_response :bad_request
  ensure
    OidcLogoutRequest.replay_store = nil
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
