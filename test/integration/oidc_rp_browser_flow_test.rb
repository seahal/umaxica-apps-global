# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpBrowserFlowTest < ActionDispatch::IntegrationTest
  COOKIE_NAME = AuthenticationBase::ACCESS_COOKIE_KEY

  SURFACES = [
    { host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      client_id: "base-rails-rp",
      acme_host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      resource: -> {
        clients(:one)
      }, },
    { host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      client_id: "base-rails-rp",
      acme_host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      resource: -> {
        operators(:one)
      }, },
    { host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      client_id: "base-rails-rp",
      acme_host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      resource: -> {
        create_visitor!
      }, },
  ].freeze

  setup do
    load_jump_rt_env!
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "app com and org sso authorize redirects to Acme OP with state nonce and PKCE" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/sso/authorize", headers: browser_headers

      assert_response :redirect
      uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal surface[:acme_host], uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal surface[:client_id], query["client_id"]
      assert_equal redirect_uri_for(surface), query["redirect_uri"]
      assert_equal "S256", query["code_challenge_method"]
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
      assert_nil query["screen_hint"]
    end
  end

  test "acme app browser flow reaches Acme token exchange without stubbing OP" do
    with_acme_oidc_client_key do
      acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
      sign_host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
      client = OidcClientRegistry.find!("base-rails-rp")
      host! acme_host

      get "/sso/authorize", headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(jump_rt_url_from_location(response.location))
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)
      code_verifier = session.fetch(:oidc_code_verifier)

      assert_equal acme_host, authorize_uri.host
      assert_equal "/oauth/authorize", authorize_uri.path

      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      assert_equal sign_host, sign_uri.host
      assert_equal "/sign/in/entrance", sign_uri.path
      assert_predicate sign_query["login_challenge"], :present?

      host! sign_host
      get sign_uri.request_uri, headers: browser_headers

      assert_response :success

      result =
        OidcAuthorizationTransactionService.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: clients(:one),
          session_ref: "acme-e2e-session",
          auth_method: "passkey",
        )

      host! acme_host
      get URI.parse(result.resume_url).request_uri, headers: browser_headers

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal URI.parse(client.redirect_uris.first).host, callback_uri.host
      assert_equal "/auth/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_equal authorize_query.fetch("state"), callback_query["state"]

      token_url = acme_app_oauth_token_url(host: acme_host)
      client_assertion = OidcClientAssertionJwt.issue(client_id: "base-rails-rp", token_url: token_url)
      post token_url,
           params: {
             grant_type: "authorization_code",
             code: callback_query.fetch("code"),
             redirect_uri: client.redirect_uris.first,
             client_id: "base-rails-rp",
             code_verifier: code_verifier,
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: client_assertion,
           },
           headers: browser_headers

      assert_response :ok
      assert_predicate response.parsed_body["id_token"], :present?
      assert_predicate response.parsed_body["access_token"], :present?
    end
  end

  test "app com and org authorization endpoints are exposed at Acme oauth authorize" do
    SURFACES.each do |surface|
      open_session do |session|
        session.host!(surface[:acme_host])

        session.get(
          "/oauth/authorize", params: {
            response_type: "code",
            client_id: surface[:client_id],
            redirect_uri: redirect_uri_for(surface),
            code_challenge: SecureRandom.urlsafe_base64(32),
            code_challenge_method: "S256",
            state: "state",
            nonce: "nonce",
            scope: "openid profile",
          }, headers: browser_headers,
        )

        if surface[:acme_host] == ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
          assert_equal 302, session.response.status, surface[:client_id]
        else
          assert_equal 422, session.response.status, surface[:client_id]
          assert_equal "Invalid request", session.response.body
        end

        session.get("/oauth/authorization", headers: browser_headers)

        assert_equal 404, session.response.status, surface[:client_id]
      end
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
    state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
    id_token = OidcIdTokenIssuer.call(
      resource: clients(:one),
      client: OidcClientRegistry.find!("base-rails-rp"),
      nonce: "wrong_nonce",
    )
    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: { id_token: id_token },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, token_result) do
      get "/auth/callback", params: { code: "code", state: state }, headers: browser_headers
    end

    assert_response :redirect
    assert_equal "http://www.app.localhost/", response.location
  end

  test "app com and org callback establishes RP session after successful authorization" do
    SURFACES.each do |surface|
      host! surface[:host]
      get "/sso/authorize", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: OidcClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )

      OidcRpTokenClient.stub(:call, token_result) do
        get "/auth/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      assert_response :redirect
      assert_equal "http://#{surface[:host]}/", response.location
      assert_response_has_auth_cookie if surface[:host] == ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    end
  end

  test "logout clears only RP session and redirects locally with Acme session-management guidance" do
    SURFACES.each do |surface|
      host! surface[:host]

      post "/sso/logout", headers: browser_headers

      assert_response :redirect
      assert_equal "http://#{surface[:host]}/", response.location
      assert_match "/settings/sessions", flash[:notice]
      assert_match surface[:acme_host], flash[:notice]
    end
  end

  test "RP only logout route does not exist" do
    post "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found

    delete "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found
  end

  private

  def redirect_uri_for(surface)
    OidcClientRegistry.find!(surface[:client_id]).redirect_uris.find do |uri|
      URI.parse(uri).host == surface[:host]
    end
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
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

  def with_acme_oidc_client_key
    original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    original_active_kid = ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"]
    key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"] = "acme-app-oidc-test"
    ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    JitSecurityJwtRegistry.reload!
    yield
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_ACME_APP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_ACME_APP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_ACME_APP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_ACME_APP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, original_issuers)
  end
end
