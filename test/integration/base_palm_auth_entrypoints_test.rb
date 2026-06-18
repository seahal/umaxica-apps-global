# typed: false
# frozen_string_literal: true

require "test_helper"

class BasePalmAuthEntrypointsTest < ActionDispatch::IntegrationTest
  fixtures_none!

  BASE_APP_HOST = ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")
  BASE_COM_HOST = ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost")
  BASE_ORG_HOST = ENV.fetch("BASE_STAFF_URL", "base.org.localhost")
  PALM_HOST = ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")

  setup do
    load_jump_rt_env!
  end

  test "base auth entrypoints redirect to acme authorize with signup intent" do
    [
      { host: BASE_APP_HOST, client_id: "base-rails-rp" },
      { host: BASE_COM_HOST, client_id: "base-rails-rp" },
      { host: BASE_ORG_HOST, client_id: "base-rails-rp" },
    ].each do |surface|
      host! surface.fetch(:host)

      get "/auth"

      assert_response :redirect
      uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(uri.query.to_s)
      redirect_uri = OidcClientRegistry.find!(surface.fetch(:client_id)).redirect_uris.first

      assert_equal URI.parse(redirect_uri).host, URI.parse(query.fetch("redirect_uri")).host
      assert_equal URI.parse(redirect_uri).path, URI.parse(query.fetch("redirect_uri")).path
      assert_equal URI.parse(redirect_uri).scheme, URI.parse(query.fetch("redirect_uri")).scheme
      assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host if surface.fetch(:host) == BASE_APP_HOST
      assert_equal ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
                   uri.host if surface.fetch(:host) == BASE_COM_HOST
      assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host if surface.fetch(:host) == BASE_ORG_HOST

      assert_equal "/oauth/authorize", uri.path
      assert_equal "base-rails-rp", query.fetch("client_id")
      assert_equal "signup", query.fetch("screen_hint")
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
    end
  end

  test "palm auth entrypoint redirects to acme authorize for the selected native client" do
    [
      { client_id: "app-ios-rp", redirect_uri: "umaxica://oauth/callback" },
      { client_id: "app-android-rp", redirect_uri: "com.umaxica.app:/oauth/callback" },
    ].each do |surface|
      host! PALM_HOST

      get "/auth", params: { client_id: surface.fetch(:client_id) }

      assert_response :redirect
      uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(uri.query.to_s)

      assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal surface.fetch(:client_id), query.fetch("client_id")
      assert_equal "signup", query.fetch("screen_hint")
      assert_equal surface.fetch(:redirect_uri), query.fetch("redirect_uri")
      assert_predicate query["state"], :present?
      assert_predicate query["nonce"], :present?
      assert_predicate query["code_challenge"], :present?
    end
  end

  test "palm auth entrypoint rejects unknown native client ids" do
    host! PALM_HOST

    get "/auth", params: { client_id: "unknown-rp" }

    assert_response :bad_request
    assert_equal "Invalid client", response.body
  end

  test "base and palm roots expose sign up links" do
    host! BASE_APP_HOST
    get "/"

    assert_response :success
    assert_select "a[href=?]", base_app_auth_authorization_path, text: "Sign up"

    host! BASE_COM_HOST
    get "/"

    assert_response :success
    assert_select "a[href=?]", base_com_auth_authorization_path, text: "Sign up"

    host! BASE_ORG_HOST
    get "/"

    assert_response :success
    assert_select "a[href=?]", base_org_auth_authorization_path, text: "Sign up"

    host! PALM_HOST
    get "/"

    assert_response :success
    assert_select "a[href=?]", palm_app_auth_authorization_path(client_id: "app-ios-rp"), text: "Sign up on iOS"
    assert_select "a[href=?]", palm_app_auth_authorization_path(client_id: "app-android-rp"), text: "Sign up on Android"
  end
end
