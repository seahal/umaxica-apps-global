# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class CoreRpBrowserFlowTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      client_id: "core-next-rp",
      acme_host: ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"),
      resource: -> { clients(:one) },
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      client_id: "core-next-rp",
      acme_host: ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      resource: -> { operators(:one) },
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      client_id: "core-next-rp",
      acme_host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      resource: -> { create_visitor! },
    },
  ].freeze

  setup do
    load_jump_rt_env!
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "regional core roots are exposed by host" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!

      get "/?ri=jp", headers: browser_headers

      assert_response :success
    end
  end

  test "regional core callback routes are host constrained" do
    expectations = {
      ENV.fetch(
        "PUBLIC_CORE_SERVICE_URL",
        ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
      ) => "core/app/auth/callbacks",
      ENV.fetch(
        "PUBLIC_CORE_CORPORATE_URL",
        ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"),
      ) => "core/com/auth/callbacks",
      ENV.fetch(
        "PUBLIC_CORE_STAFF_URL",
        ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"),
      ) => "core/org/auth/callbacks",
      "core.app.localhost" => "core/app/auth/callbacks",
      "core.com.localhost" => "core/com/auth/callbacks",
      "core.org.localhost" => "core/org/auth/callbacks",
    }

    expectations.each do |host, controller|
      assert_routing(
        { method: :get, path: "http://#{host}/oidc/callback" },
        { controller: controller, action: "show", to: "/#{controller}#show" },
      )
    end
  end

  test "regional core auth authorize redirects to Acme OP with state nonce and PKCE" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!

      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal surface[:acme_host], uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_not_equal "jump.umaxica.net", uri.host
      assert_equal surface[:client_id], query["client_id"]
      assert_equal redirect_uri_for(surface), query["redirect_uri"]
      assert_equal "signup", query["screen_hint"]
      assert_equal "S256", query["code_challenge_method"]
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
    end
  end

  test "core app browser flow reaches Acme token exchange without stubbing OP" do
    with_core_oidc_client_key do
      core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))
      acme_host = ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")
      sign_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
      client = OidcClientRegistry.find!("core-next-rp")
      host! core_host
      https!

      get "/oidc/authorization", headers: browser_headers

      assert_response :redirect
      authorize_uri = URI.parse(response.location)
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)
      code_verifier = session.fetch(:oidc_code_verifier)

      assert_equal acme_host, authorize_uri.host
      assert_equal "/oauth/authorize", authorize_uri.path
      assert_not_equal "jump.umaxica.net", authorize_uri.host

      host! acme_host
      get "/oauth/authorize", params: authorize_query, headers: browser_headers

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)

      assert_equal sign_host, sign_uri.host
      assert_equal "/sign/up", sign_uri.path
      assert_predicate sign_query["login_challenge"], :present?

      host! sign_host
      get sign_uri.request_uri, headers: browser_headers

      assert_response :success
      assert_equal sign_query["login_challenge"], session[:oidc_authorization_login_challenge]

      result =
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: sign_query.fetch("login_challenge"),
          actor: clients(:one),
          session_ref: "core-e2e-session",
          auth_method: "passkey",
        )

      host! acme_host
      get URI.parse(result.resume_url).request_uri, headers: browser_headers

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal URI.parse(client.redirect_uris.first).host, callback_uri.host
      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_equal authorize_query.fetch("state"), callback_query["state"]

      token_url = acme_app_oauth_token_url(host: acme_host)
      client_assertion = OidcClientAssertionJwt.issue(client_id: "core-next-rp", token_url: token_url)
      post token_url,
           params: {
             grant_type: "authorization_code",
             code: callback_query.fetch("code"),
             redirect_uri: client.redirect_uris.first,
             client_id: "core-next-rp",
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

  test "regional core callback establishes RP session after successful authorization" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!
      get "/oidc/authorization", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      resource_type = oidc_resource_type_for(resource)
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: OidcClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: OidcIssuer.for_resource_type(resource_type),
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )

      OidcRpTokenClient.stub(:call, token_result) do
        get "/oidc/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      assert_response :redirect
      assert_equal "https://#{surface[:host]}/", response.location
      assert_core_bridge_exists_for(surface[:client_id], resource) if resource.is_a?(Client)
    end
  end

  test "regional core logout clears only RP session and redirects locally with Acme guidance" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!
      get "/oidc/authorization", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      resource_type = oidc_resource_type_for(resource)
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: OidcClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: OidcIssuer.for_resource_type(resource_type),
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )
      OidcRpTokenClient.stub(:call, token_result) do
        get "/oidc/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      post "/sign/out", headers: browser_headers

      assert_response :success
      assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
      logout_uri = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
      logout_query = Rack::Utils.parse_nested_query(logout_uri.query.to_s)

      assert_equal "/oidc/logout", logout_uri.path
      assert_predicate logout_query["id_token_hint"], :present?
      assert_includes logout_query.fetch("post_logout_redirect_uri", ""), surface[:host]
    end
  end

  test "regional core logout remains local after a successful callback" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!
      get "/oidc/authorization", headers: browser_headers

      state = Rack::Utils.parse_nested_query(URI.parse(jump_rt_url_from_location(response.location)).query).fetch("state")
      resource = instance_exec(&surface[:resource])
      resource_type = oidc_resource_type_for(resource)
      id_token = OidcIdTokenIssuer.call(
        resource: resource,
        client: OidcClientRegistry.find!(surface[:client_id]),
        nonce: session.fetch(:oidc_nonce),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
        issuer: OidcIssuer.for_resource_type(resource_type),
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: { id_token: id_token },
        error: nil,
      )

      OidcRpTokenClient.stub(:call, token_result) do
        get "/oidc/callback", params: { code: "code", state: state }, headers: browser_headers
      end

      assert_response :redirect

      post "/sign/out", headers: browser_headers

      assert_response :success
      assert_select "form#sign-out-handoff-form[method=?]", "post", count: 1
      logout_uri = URI.parse(css_select("form#sign-out-handoff-form").first["action"])
      logout_query = Rack::Utils.parse_nested_query(logout_uri.query.to_s)

      assert_equal "/oidc/logout", logout_uri.path
      assert_predicate logout_query["id_token_hint"], :present?
      assert_includes logout_query.fetch("post_logout_redirect_uri", ""), surface[:host]
    end
  end

  private

  def oidc_resource_type_for(resource)
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    end
  end

  def redirect_uri_for(surface)
    OidcClientRegistry.find!(surface[:client_id]).redirect_uris.find do |uri|
      URI.parse(uri).host == surface[:host]
    end
  end

  def with_core_oidc_client_key
    original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    original_active_kid = ENV["OIDC_CLIENT_CORE_APP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_CORE_APP_PRIVATE_KEY"]
    key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_CORE_APP_ACTIVE_KID"] = "core-app-oidc-test"
    ENV["OIDC_CLIENT_CORE_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    JitSecurityJwtRegistry.reload!
    yield
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_CORE_APP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_CORE_APP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_CORE_APP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_CORE_APP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, original_issuers)
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    Visitor.create!(status_id: VisitorStatus::NOTHING)
  end

  def assert_core_bridge_exists_for(_client_id, resource)
    case resource
    when Client

      assert_predicate CoreAppClientBridge.find_by!(client_id: resource.id), :core?
    when Operator

      assert_predicate CoreOrgOperatorBridge.find_by!(operator_id: resource.id), :core?
    when Visitor

      assert_predicate CoreComVisitorBridge.find_by!(visitor_id: resource.id), :core?
    else
      flunk("unexpected core resource: #{resource.class.name}")
    end
  end
end
