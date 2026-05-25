# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpBrowserFlowTest < ActionDispatch::IntegrationTest
  COOKIE_NAME = Authentication::Base::ACCESS_COOKIE_KEY

  SURFACES = [
    { host: "www.app.localhost", client_id: "apex_app", sign_host: "id.app.localhost", resource: -> { clients(:one) } },
    { host: "www.org.localhost",
      client_id: "apex_org",
      sign_host: "id.org.localhost",
      resource: -> {
        operators(:one)
      }, },
    { host: "www.com.localhost",
      client_id: "apex_com",
      sign_host: "id.com.localhost",
      resource: -> {
        create_visitor!
      }, },
  ].freeze

  test "app com and org sso authorize redirects to IdP with state nonce and PKCE" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/sso/authorize", headers: browser_headers

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal surface[:sign_host], uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal surface[:client_id], query["client_id"]
      assert_equal "S256", query["code_challenge_method"]
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
      assert_nil query["screen_hint"]
    end
  end

  test "app com and org old sign entry routes are not exposed" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/sign", headers: browser_headers

      assert_response :not_found

      get "/sign/in", headers: browser_headers

      assert_response :not_found

      get "/sign/up", headers: browser_headers

      assert_response :not_found
    end
  end

  test "callback rejects state mismatch" do
    host! "www.app.localhost"
    get "/sso/authorize", headers: browser_headers

    get "/auth/callback", params: { code: "code", state: "wrong" }, headers: browser_headers

    assert_response :unprocessable_entity
  end

  test "callback rejects nonce mismatch" do
    host! "www.app.localhost"
    get "/sso/authorize", headers: browser_headers
    state = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("state")
    id_token = Oidc::IdTokenIssuer.call(
      resource: clients(:one),
      client: Oidc::ClientRegistry.find!("apex_app"),
      nonce: "wrong_nonce",
    )
    token_result = Oidc::RpTokenClient::Result.new(
      success: true,
      token_response: { id_token: id_token },
      error: nil,
    )

    Oidc::RpTokenClient.stub(:call, token_result) do
      get "/auth/callback", params: { code: "code", state: state }, headers: browser_headers
    end

    assert_response :redirect
    assert_equal "http://www.app.localhost/", response.location
  end

  test "app com and org callback establishes RP session after successful authorization" do
    SURFACES.each do |surface|
      host! surface[:host]
      get "/sso/authorize", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      id_token = Oidc::IdTokenIssuer.call(
        resource: resource,
        client: Oidc::ClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
      )
      token_result = Oidc::RpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )

      Oidc::RpTokenClient.stub(:call, token_result) do
        get "/auth/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      assert_response :redirect
      assert_equal "http://#{surface[:host]}/", response.location
      assert_response_has_auth_cookie

      get "/?ri=jp", headers: browser_headers

      assert_response :success
      assert_select "form[action^=?][method=?]", "/sso/logout", "post"
    end
  end

  test "logout is full logout redirect to IdP logout" do
    SURFACES.each do |surface|
      host! surface[:host]

      post "/sso/logout", headers: browser_headers

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal surface[:sign_host], uri.host
      assert_equal "/oidc/logout", uri.path
      assert_equal surface[:client_id], query["client_id"]
      assert_predicate query["logout_request"], :present?
      assert_nil query["post_logout_redirect_uri"]
    end
  end

  test "RP only logout route does not exist" do
    post "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found

    delete "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found
  end

  private

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMultiFactor.find_or_create_by!(id: VisitorMultiFactor::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end

  def assert_response_has_auth_cookie
    assert_includes response.headers["Set-Cookie"].to_s, "#{COOKIE_NAME}=",
                    "expected callback response to set #{COOKIE_NAME}"
  end
end
