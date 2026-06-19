# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/auth_helpers"

class Acme::App::Oidc::LogoutsControllerTest < ActionDispatch::IntegrationTest
  include AuthHelpers

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @client = OidcClientRegistry.find!("sign-rp")
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @session_public_id = @token.public_id
    set_access_cookie(acme_access_token(@user, resource_type: "client", jwt_issuer_id: "surface:ACME_APP"))
  end

  test "routes get and post to oidc logout without changing helper" do
    get_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    post_route = Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :post)

    assert_equal "acme/app/oidc/logouts", get_route[:controller]
    assert_equal "show", get_route[:action]
    assert_equal "acme/app/oidc/logouts", post_route[:controller]
    assert_equal "create", post_route[:action]
    assert_equal "/oidc/logout", acme_app_oidc_logout_path
  end

  test "get without params renders confirmation without mutation" do
    get acme_app_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_no_auth_cookie_clear
    assert_nil response.location
  end

  test "post without params does not silently logout" do
    post acme_app_oidc_logout_url(host: @host), params: { ri: "jp" }, headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_no_auth_cookie_clear
    assert_nil response.location
  end

  test "valid id_token_hint on get renders confirmation without mutation" do
    get acme_app_oidc_logout_url(host: @host),
        params: { id_token_hint: id_token, ri: "jp" },
        headers: session_headers

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_no_auth_cookie_clear
    assert_nil response.location
  end

  # HEAD shares the GET route in Rails; it must not trigger logout side effects even with a valid hint.
  test "valid id_token_hint on head does not mutate session" do
    assert_no_enqueued_jobs only: OidcBackchannelLogoutDeliveryJob do
      head acme_app_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, ri: "jp" },
           headers: session_headers
    end

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?
    assert_no_auth_cookie_clear
    assert_nil response.location
  end

  test "valid id_token_hint on post logs out and redirects to the completion path" do
    assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
      post acme_app_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, ri: "jp" },
           headers: session_headers
    end

    assert_response :see_other
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "0", response.headers["Expires"]
    assert_predicate @token.reload, :revoked?
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal "/sign/out", location.path
    assert_equal "jp", query["ri"]
    assert_predicate query["sot"], :present?

    completion_location = location.request_uri

    get completion_location, headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "0", response.headers["Expires"]

    get completion_location, headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_equal "logout completion is stale", response.parsed_body.fetch("error_description")
  end

  test "preference normalization keeps sign out completion token intact" do
    assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
      post acme_app_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, ri: "jp" },
           headers: session_headers
    end

    completion_location = URI.parse(response.location).request_uri

    assert_includes completion_location, "sot="
    assert_not_includes completion_location, "ct="

    get completion_location, headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "valid id_token_hint on post enqueues multiple backchannel deliveries without n plus one queries" do
    client = OidcClientRegistry.find!("sign-rp")
    uris = [
      "https://id.app.localhost/oidc/backchannel_logout",
      "https://id2.app.localhost/oidc/backchannel_logout",
    ]

    OidcClientRegistry.stub(:logout_clients_for_resource_type, [client]) do
      OidcClientRegistry.stub(:backchannel_logout_uris_for, uris) do
        assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
          post acme_app_oidc_logout_url(host: @host),
               params: { id_token_hint: id_token, ri: "jp" },
               headers: session_headers
        end
      end
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
  end

  test "invalid id_token_hint signature does not mutate or redirect externally" do
    post acme_app_oidc_logout_url(host: @host),
         params: { id_token_hint: "#{id_token}x", ri: "jp" },
         headers: session_headers

    assert_response :bad_request
    assert_not_predicate @token.reload, :revoked?
    assert_no_auth_cookie_clear
    assert_nil response.location
  end

  test "mismatched subject does not mutate or redirect externally" do
    other = clients(:two)
    bad_hint = id_token(resource: other, subject: OidcSubject.for(other, resource_type: "client"))

    post acme_app_oidc_logout_url(host: @host),
         params: { id_token_hint: bad_hint, ri: "jp" },
         headers: session_headers

    assert_response :bad_request
    assert_not_predicate @token.reload, :revoked?
    assert_nil response.location
  end

  test "registered post_logout_redirect_uri receives state after logout" do
    redirect_uri = @client.post_logout_redirect_uris.first

    assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob do
      post acme_app_oidc_logout_url(host: @host),
           params: { id_token_hint: id_token, post_logout_redirect_uri: redirect_uri, state: "xyz", ri: "jp" },
           headers: session_headers
    end

    assert_response :see_other
    assert_predicate @token.reload, :revoked?
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal URI.parse(redirect_uri).host, location.host
    assert_equal "/sign/out", location.path
    assert_equal "xyz", query["state"]
  end

  test "unregistered post_logout_redirect_uri never redirects or leaks state" do
    post acme_app_oidc_logout_url(host: @host),
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
    logout_request = OidcLogoutRequest.issue(client_id: "base-rails-rp", ri: "jp")

    get(
      acme_app_oidc_logout_url(host: @host),
      params: { logout_request: logout_request, client_id: "base-rails-rp", ri: "jp" },
      headers: session_headers,
    )

    assert_response :ok
    assert_not_predicate @token.reload, :revoked?

    post(
      acme_app_oidc_logout_url(host: @host),
      params: { logout_request: logout_request, client_id: "base-rails-rp", ri: "jp" },
      headers: session_headers,
    )

    assert_response :see_other
    assert_predicate @token.reload, :revoked?

    post(
      acme_app_oidc_logout_url(host: @host),
      params: { logout_request: logout_request, client_id: "base-rails-rp", ri: "jp" },
      headers: session_headers,
    )

    assert_response :bad_request
  end

  private

  def session_headers
    browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
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

  def id_token(resource: @user, subject: OidcSubject.for(@user, resource_type: "client"), sid: @session_public_id)
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

  def assert_no_auth_cookie_clear
    assert_not response_has_cookie?(AuthenticationBase::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(AuthenticationBase::REFRESH_COOKIE_KEY)
  end
end
