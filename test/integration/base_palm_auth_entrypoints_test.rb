# typed: false
# frozen_string_literal: true

require "test_helper"

class BasePalmAuthEntrypointsTest < ActionDispatch::IntegrationTest
  fixtures_none!

  BASE_APP_HOST = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  BASE_COM_HOST = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  BASE_ORG_HOST = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
  PALM_HOST = ENV.fetch("PALM_SERVICE_URL")

  setup do
    load_jump_rt_env!
  end

  test "base auth entrypoints redirect to acme authorize with base callback and signup intent" do
    [
      { host: BASE_APP_HOST, acme_host: ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost") },
      { host: BASE_COM_HOST, acme_host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost") },
      { host: BASE_ORG_HOST, acme_host: ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost") },
    ].each do |surface|
      host! surface.fetch(:host)

      get "/oidc/authorization"

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query.to_s)

      redirect_uri = URI.parse(query.fetch("redirect_uri"))

      assert_equal surface.fetch(:acme_host), uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_not_equal "jump.umaxica.net", uri.host
      assert_equal "base-rails-rp", query.fetch("client_id")
      assert_equal "signup", query.fetch("screen_hint")
      assert_equal surface.fetch(:host), redirect_uri.host
      assert_equal "/oidc/callback", redirect_uri.path
      assert_equal uri.scheme, redirect_uri.scheme
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
      assert_equal query.fetch("state"), session[:oidc_state]
      assert_predicate session[:oidc_code_verifier], :present?
    end
  end

  test "palm auth entrypoint redirects to acme authorize for the selected native client" do
    [
      { client_id: "app-ios-rp", redirect_uri: "umaxica://oidc/callback" },
      { client_id: "app-android-rp", redirect_uri: "com.umaxica.app:/oidc/callback" },
    ].each do |surface|
      host! PALM_HOST

      get "/oidc/authorization", params: { client_id: surface.fetch(:client_id) }

      assert_response :redirect
      uri = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(uri.query.to_s)

      assert_equal ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"), uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_not_equal "jump.umaxica.net", uri.host
      assert_equal surface.fetch(:client_id), query.fetch("client_id")
      assert_equal "signup", query.fetch("screen_hint")
      assert_equal surface.fetch(:redirect_uri), query.fetch("redirect_uri")
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
    end
  end

  test "palm auth entrypoint can request sign in intent for the selected native client" do
    host! PALM_HOST

    get "/oidc/authorization", params: { client_id: "app-ios-rp", screen_hint: "signin" }

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host
    assert_equal "app-ios-rp", query.fetch("client_id")
    assert_equal "signin", query.fetch("screen_hint")
    assert_equal "umaxica://oidc/callback", query.fetch("redirect_uri")
  end

  test "palm auth entrypoint rejects unknown native client ids" do
    host! PALM_HOST

    get "/oidc/authorization", params: { client_id: "unknown-rp" }

    assert_response :bad_request
    assert_equal "Invalid client", response.body
  end

  test "base callback routes are host constrained" do
    {
      BASE_APP_HOST => "base/app/auth/callbacks",
      BASE_COM_HOST => "base/com/auth/callbacks",
      BASE_ORG_HOST => "base/org/auth/callbacks",
    }.each do |host, controller|
      assert_routing(
        { method: :get, path: "http://#{host}/oidc/callback" },
        { controller: controller, action: "show", to: "/#{controller}#show" },
      )
    end
  end

  test "base callbacks reject requests without rp state" do
    [BASE_APP_HOST, BASE_COM_HOST, BASE_ORG_HOST].each do |host|
      host! host

      get "/oidc/callback", params: { code: "code", state: "state" }

      assert_response :unprocessable_content
      assert_equal I18n.t("errors.messages.login_required"), response.body
    end
  end

  test "base and palm roots expose sign up links" do
    host! BASE_APP_HOST
    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "a[href=?]", base_app_oidc_authorization_path(ri: "jp"), text: "Sign up"

    host! BASE_COM_HOST
    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "a[href=?]", base_com_oidc_authorization_path(ri: "jp"), text: "Sign up"

    host! BASE_ORG_HOST
    get "/", params: { ri: "jp" }

    assert_response :success
    assert_select "a[href=?]", base_org_oidc_authorization_path(ri: "jp"), text: "Sign up"

    host! PALM_HOST
    get "/"

    assert_response :success
    assert_select "a[href=?]", palm_app_oidc_authorization_path(client_id: "app-ios-rp"), text: "Sign up on iOS"
    assert_select "a[href=?]", palm_app_oidc_authorization_path(client_id: "app-android-rp"), text: "Sign up on Android"
  end
end
