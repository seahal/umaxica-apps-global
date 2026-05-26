# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreRpBrowserFlowTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"),
      client_id: "core_app",
      sign_host: ENV.fetch("ID_SERVICE_URL", "id.umaxica.app"),
      resource: -> { clients(:one) },
    },
    {
      host: ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"),
      client_id: "core_org",
      sign_host: ENV.fetch("ID_STAFF_URL", "id.umaxica.org"),
      resource: -> { operators(:one) },
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
      client_id: "core_com",
      sign_host: ENV.fetch("ID_CORPORATE_URL", "id.umaxica.com"),
      resource: -> { create_visitor! },
    },
  ].freeze

  setup do
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
      ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app") => "core/app/auth/callbacks",
      ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com") => "core/com/auth/callbacks",
      ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org") => "core/org/auth/callbacks",
    }

    expectations.each do |host, controller|
      assert_routing(
        { method: :get, path: "http://#{host}/auth/callback" },
        { controller: controller, action: "show" },
      )
    end
  end

  test "regional core sso authorize redirects to IdP with state nonce and PKCE" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!

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
    end
  end

  test "regional core accounts require matching core OIDC clients" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!

      get "/accounts?ri=jp", headers: browser_headers

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query)

      assert_equal surface[:sign_host], uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal surface[:client_id], query["client_id"]
      assert_equal Oidc::ClientRegistry.find!(surface[:client_id]).redirect_uris.first, query["redirect_uri"]
    end
  end

  test "regional core callback establishes RP session after successful authorization" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!
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
      assert_equal "https://#{surface[:host]}/", response.location
      assert_core_bridge_exists_for(surface[:client_id], resource)

      get "/accounts?ri=jp", headers: browser_headers

      assert_response :success
      assert_includes response.body, "account"
    end
  end

  test "regional core logout redirects to IdP logout" do
    SURFACES.each do |surface|
      host! surface[:host]
      https!

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

  private

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMultiFactor.find_or_create_by!(id: VisitorMultiFactor::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    Visitor.create!(status_id: VisitorStatus::NOTHING)
  end

  def assert_core_bridge_exists_for(client_id, resource)
    case client_id
    when "core_app"
      assert_predicate CoreAppClientBridge.find_by!(client_id: resource.id), :core?
    when "core_org"
      assert_predicate CoreOrgOperatorBridge.find_by!(operator_id: resource.id), :core?
    when "core_com"
      assert_predicate CoreComVisitorBridge.find_by!(visitor_id: resource.id), :core?
    else
      flunk("unexpected core client_id: #{client_id}")
    end
  end
end
