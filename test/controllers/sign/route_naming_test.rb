# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::RouteNamingTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    com: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
    org: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
  }.freeze

  test "sign entry helpers use explicit lifecycle resources" do
    assert_equal "/sign/up", sign_app_sign_up_path
    assert_equal "/sign/in", sign_app_sign_in_path
  end

  test "sign logout mutation helpers stay absent while completion page is present" do
    helpers = Rails.application.routes.url_helpers

    assert_respond_to helpers, :sign_app_sign_out_path
    assert_not_respond_to helpers, :edit_sign_app_sign_out_path
    assert_not_respond_to helpers, :sign_app_sign_out_confirmation_path
    assert_not_respond_to helpers, :sign_app_sign_out_attempt_path
    assert_not_respond_to helpers, :sign_app_sign_out_completion_path
  end

  test "top-level sign entry routes resolve conventionally on every sign surface" do
    SURFACES.each_key do |surface|
      assert_recognizes_sign_route(surface, "/sign/up", :get, "sign/ups", "show")
      assert_recognizes_sign_route(surface, "/sign/in", :get, "sign/ins", "show")
      assert_unrecognized(surface, "/sign/up/entrance", :get)
      assert_unrecognized(surface, "/sign/in/entrance", :get)
      assert_recognizes_sign_route(surface, "/sign/out", :get, (surface == :app) ? "sign_outs" : "sign/outs", "show")
      assert_unrecognized(surface, "/signed-out", :get)
      assert_recognizes_sign_route(surface, "/oidc/backchannel/logout", :post, "oidc/backchannel/logouts", "create")
      assert_unrecognized(surface, "/oidc/frontchannel_logout", :get)
      assert_unrecognized(surface, "/sign/out/confirmation", :get)
      assert_unrecognized(surface, "/sign/out/attempt", :post)
      assert_unrecognized(surface, "/sign/out/completion", :get)
    end
  end

  test "sign check routes use checks controller namespace and old checkpoint route is absent" do
    assert_recognizes_sign_route(:app, "/sign/in/check", :get, "sign/in/checks", "show")
    assert_recognizes_sign_route(:app, "/sign/in/check", :patch, "sign/in/checks", "update")
    assert_recognizes_sign_route(:com, "/sign/in/check", :get, "sign/in/checks", "show")
    assert_recognizes_sign_route(:org, "/sign/in/check", :get, "sign/in/checks", "show")

    SURFACES.each_key do |surface|
      assert_unrecognized(surface, "/sign/in/check", :delete)
      assert_unrecognized(surface, "/sign/in/checkpoint", :get)
      assert_unrecognized(surface, "/sign/in/checkpoint", :patch)
      assert_unrecognized(surface, "/sign/in/checkpoint", :delete)
    end
  end

  test "app social routes are provider explicit and com org social routes are absent" do
    assert_recognizes_sign_route(:app, "/social/apple/sign/in", :post, "social/authentications", "continue")
    assert_recognizes_sign_route(:app, "/social/apple/sign/up", :post, "social/authentications", "continue")
    assert_recognizes_sign_route(:app, "/social/google/sign/in", :post, "social/authentications", "continue")
    assert_recognizes_sign_route(:app, "/social/google/sign/up", :post, "social/authentications", "continue")
    assert_recognizes_sign_route(:app, "/social/google/callback", :get, "auth/omniauth_callbacks", "omniauth")
    assert_recognizes_sign_route(:app, "/social/apple/callback", :get, "auth/omniauth_callbacks", "omniauth")
    assert_recognizes_sign_route(:app, "/social/apple/callback", :post, "auth/omniauth_callbacks", "omniauth")
    assert_recognizes_sign_route(:app, "/social/failure", :get, "auth/omniauth_callbacks", "failure")

    assert_unrecognized(:app, "/social/apple/connection_attempt", :post)
    assert_unrecognized(:app, "/social/google/disconnection_attempt", :post)
    assert_unrecognized(:app, "/social/apple/sign/in", :delete)
    assert_unrecognized(:app, "/social/google/sign/in", :delete)
    assert_unrecognized(:com, "/social/apple/connection", :get)
    assert_unrecognized(:org, "/social/google/connection", :get)
  end

  test "preference routes are not exposed on sign" do
    assert_unrecognized(:app, "/preference/language/edit", :get)
  end

  test "settings mfa reset resolves through conventional settings mfa namespace" do
    assert_recognizes_sign_route(:app, "/settings/mfa/reset", :get, "settings/mfa/resets", "show")
    assert_recognizes_sign_route(:app, "/settings/mfa/reset", :post, "settings/mfa/resets", "create")
  end

  test "session revocation uses post routes instead of collection deletes" do
    assert_recognizes_sign_route(
      :app, "/settings/sessions/abc/revocation", :post,
      "settings/revocations", "create",
    )
    assert_recognizes_sign_route(
      :app, "/settings/revocations/others", :post,
      "settings/revocations/others", "create",
    )
    assert_recognizes_sign_route(
      :app, "/settings/revocations/all", :post,
      "settings/revocations/alls", "create",
    )

    assert_unrecognized(:app, "/settings/sessions/abc/revocation_attempt", :post)
    assert_unrecognized(:app, "/settings/session_revocations/others", :post)
    assert_unrecognized(:app, "/settings/sessions/others", :delete)
    assert_unrecognized(:app, "/settings/sessions/revoke_all", :delete)
  end

  test "route source excludes sign routing compatibility patterns" do
    source = Rails.root.join("config/routes/sign.rb").read

    forbidden = [
      "safe_sign_state_" + "redirect",
      'scope path: "' + 'sign"',
      'path: "' + 'in"',
      'path: "' + 'out"',
      'controller: "' + 'sign_ins"',
      'controller: "' + 'sign_outs"',
      'controller: "' + 'checkpoints"',
      "defaults: { preference_" + "screen:",
      "param: :" + "provider",
      'module: "' + 'settings/mfa"',
      "post :" + "continue",
      "post :" + "resend",
      "post :" + "regenerate",
      "delete :" + "others",
      "delete :" + "revoke_all",
      "resource :openid_" + "configuration",
      "namespace :" + "oauth",
      "resource :" + "refresh",
    ]

    forbidden.each { |pattern| assert_not_includes source, pattern }
  end

  private

  def assert_recognizes_sign_route(surface, path, method, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{SURFACES.fetch(surface)}#{path}", method: method)

    assert_equal "sign/#{surface}/#{controller_name}", route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_unrecognized(surface, path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{SURFACES.fetch(surface)}#{path}", method: method)
    end
  end
end
