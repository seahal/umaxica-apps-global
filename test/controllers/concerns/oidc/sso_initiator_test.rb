# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSsoInitiatorTestController < ApplicationController
  include OidcSsoInitiator

  def index
    authenticate!
    head :ok unless performed?
  end

  def logged_in?
    request.headers["X-Logged-In"] == "1"
  end

  def current_resource
    Struct.new(:id).new(42)
  end

  def oidc_client_id
    "base-rails-rp"
  end

  def oidc_sign_host
    "log.umaxica.app"
  end

  def oidc_acme_host
    "www.umaxica.app"
  end

  def oidc_callback_url
    "https://www.umaxica.app/oidc/callback"
  end

  def jump_rt_issuer_namespace
    "ACME_APP"
  end
end

class OidcSsoInitiatorTest < ActionDispatch::IntegrationTest
  setup do
    load_jump_rt_env!
    Rails.application.routes.draw do
      get "/oidc/sso" => "oidc_sso_initiator_test#index"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "authenticate! redirects unauthenticated html requests to oidc authorize url" do
    io = StringIO.new
    logger = Logger.new(io)

    Rails.stub(:logger, logger) do
      get "/oidc/sso", headers: { "Host" => "log.umaxica.app" }
    end

    assert_response :redirect
    location = response.location
    uri = URI.parse(location)

    assert_equal "www.umaxica.app", uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_not_equal "jump.umaxica.net", uri.host

    authorize_params = Rack::Utils.parse_nested_query(uri.query)

    assert_equal "base-rails-rp", authorize_params.fetch("client_id")
    assert_equal "https://www.umaxica.app/oidc/callback", authorize_params.fetch("redirect_uri")
    assert_predicate session[:oidc_code_verifier], :present?
    assert_predicate session[:oidc_state], :present?
    assert_equal "/oidc/sso", session[:oidc_pt]
    pending_flow = session.fetch("oidc_pending_flows").fetch(session[:oidc_state])

    assert_equal session[:oidc_code_verifier], pending_flow.fetch("code_verifier")
    assert_equal session[:oidc_nonce], pending_flow.fetch("nonce")
    assert_equal "/oidc/sso", pending_flow.fetch("pt")
    assert_includes io.string, "oidc.sso.redirect_policy.direct"
    assert_includes io.string, "reason_code"
    assert_includes io.string, "target_host"
    assert_not_includes io.string, session[:oidc_state]
    assert_not_includes io.string, session[:oidc_nonce]
    assert_not_includes io.string, session[:oidc_code_verifier]
    assert_not_includes io.string, response.location
    assert_not_includes io.string, "oauth/authorize?"
  end

  test "authenticate! preserves the protected request query in oidc return path" do
    get "/oidc/sso", params: { ri: "jp" }, headers: { "Host" => "log.umaxica.app" }

    assert_response :redirect
    assert_equal "/oidc/sso?ri=jp", session[:oidc_pt]

    pending_flow = session.fetch("oidc_pending_flows").fetch(session[:oidc_state])

    assert_equal "/oidc/sso?ri=jp", pending_flow.fetch("pt")
  end

  test "token endpoint uses local rails port for local public Acme hosts" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => "log.umaxica.app",
      "HTTPS" => "on",
    )

    with_env("PORT" => "3000") do
      assert_equal "http://www.umaxica.app:3000/oauth/token", controller.send(:oidc_token_url)
    end
  end

  test "token endpoint keeps public https origin outside local environments" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => "log.umaxica.app",
      "HTTPS" => "on",
    )

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_equal "https://www.umaxica.app/oauth/token", controller.send(:oidc_token_url)
    end
  end

  test "token endpoint local rewrite is limited to configured Acme hosts" do
    OidcSsoInitiatorTestController.define_method(:oidc_acme_host) { "www-jp.umaxica.app" }
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create(
      "HTTP_HOST" => "log.umaxica.app",
      "HTTPS" => "on",
    )

    with_env("PORT" => "3000") do
      assert_equal "https://www-jp.umaxica.app/oauth/token", controller.send(:oidc_token_url)
    end
  ensure
    OidcSsoInitiatorTestController.define_method(:oidc_acme_host) { "www.umaxica.app" }
  end

  test "authenticate! keeps using jump for cross-site oidc authorize urls" do
    OidcSsoInitiatorTestController.define_method(:oidc_acme_host) { "www.umaxica.com" }
    OidcSsoInitiatorTestController.define_method(:oidc_callback_url) do
      "https://www.umaxica.com/oidc/callback"
    end

    io = StringIO.new
    logger = Logger.new(io)

    Rails.stub(:logger, logger) do
      get("/oidc/sso", headers: { "Host" => "log.umaxica.app" })
    end

    assert_response :redirect
    assert_equal "jump.umaxica.net", URI.parse(response.location).host
    location = jump_rt_url_from_location(response.location)

    assert_match %r{\Ahttps://www\.umaxica\.com/oauth/authorize\?}, location
    assert_includes io.string, "oidc.sso.redirect_policy.jump"
    assert_includes io.string, "reason_code"
    assert_includes io.string, "site_mismatch"
    assert_not_includes io.string, "state"
    assert_not_includes io.string, "nonce"
    assert_not_includes io.string, "code_challenge"
  ensure
    OidcSsoInitiatorTestController.define_method(:oidc_acme_host) { "www.umaxica.app" }
    OidcSsoInitiatorTestController.define_method(:oidc_callback_url) do
      "https://www.umaxica.app/oidc/callback"
    end
  end

  test "safe_oidc_pt strips foreign hosts" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "http://attacker.example/evil")
    assert_equal "/", controller.send(:safe_oidc_pt, "https://attacker.example/evil")
    assert_equal "/", controller.send(:safe_oidc_pt, "https://www.umaxica.app/oauth/authorize?client_id=base-rails-rp")
  end

  test "safe_oidc_pt rejects scheme based payloads" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "javascript:alert(1)")
    assert_equal "/", controller.send(:safe_oidc_pt, "data:text/html,<script>")
    assert_equal "/", controller.send(:safe_oidc_pt, "//attacker.example/")
  end

  test "safe_oidc_pt rejects userinfo even when host matches" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "http://attacker@www.example.com/path")
    assert_equal "/", controller.send(:safe_oidc_pt, "http://user:pw@www.example.com/path")
  end

  test "safe_oidc_pt rejects control characters" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/", controller.send(:safe_oidc_pt, "/foo\r\nSet-Cookie: x=1")
    assert_equal "/", controller.send(:safe_oidc_pt, "/foo\x00bar")
  end

  test "safe_oidc_pt returns same-host internal path only" do
    controller = OidcSsoInitiatorTestController.new
    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "www.example.com")

    assert_equal "/oidc/sso", controller.send(:safe_oidc_pt, "http://www.example.com/oidc/sso")
    assert_equal "/oidc/sso?ri=jp", controller.send(:safe_oidc_pt, "http://www.example.com/oidc/sso?ri=jp")
    assert_equal "/already/relative", controller.send(:safe_oidc_pt, "/already/relative")
  end

  test "authenticate! renders unauthorized json for unauthenticated json requests" do
    get "/oidc/sso", as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "authenticate! calls risk enforcer for logged in clients" do
    called = false

    SignRiskEnforcer.stub(:call, ->(_resource) { called = true }) do
      get "/oidc/sso", headers: { "X-Logged-In" => "1" }
    end

    assert_response :ok
    assert called
  end

  private

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
