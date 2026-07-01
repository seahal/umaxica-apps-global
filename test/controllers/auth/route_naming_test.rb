# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::RouteNamingTest < ActionDispatch::IntegrationTest
  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = {
    app: BOOT_HOSTS.sign_service.host,
    com: BOOT_HOSTS.sign_corporate.host,
    org: BOOT_HOSTS.sign_staff.host,
  }.freeze

  test "sign entry helpers use explicit lifecycle resources" do
    assert_equal "/sign/up", auth_app_sign_up_path
    assert_equal "/sign/in", auth_app_sign_in_path
  end

  test "sign logout helpers expose the explicit ceremony lifecycle" do
    helpers = Rails.application.routes.url_helpers

    assert_respond_to helpers, :auth_app_sign_out_path
    assert_respond_to helpers, :new_auth_app_sign_out_path
    assert_respond_to helpers, :edit_auth_app_sign_out_path
    assert_respond_to helpers, :auth_app_sign_out_completion_path
    assert_not_respond_to helpers, :auth_app_sign_out_confirmation_path
    assert_not_respond_to helpers, :auth_app_sign_out_attempt_path
    assert_not_respond_to helpers, :complete_auth_app_sign_out_path
  end

  test "top-level sign entry routes resolve conventionally on every sign surface" do
    SURFACES.each_key do |surface|
      assert_recognizes_sign_route(surface, "/sign/up", :get, "auth/#{surface}/sign/ups", "show")
      assert_recognizes_sign_route(surface, "/sign/in", :get, "auth/#{surface}/sign/ins", "show")
      assert_unrecognized(surface, "/sign/up/entrance", :get)
      assert_unrecognized(surface, "/sign/in/entrance", :get)
      assert_recognizes_sign_route(surface, "/sign/out/new", :get, "auth/#{surface}/sign/outs", "new")
      assert_recognizes_sign_route(surface, "/sign/out/edit", :get, "auth/#{surface}/sign/outs", "edit")
      assert_recognizes_sign_route(surface, "/sign/out/complete", :get, "auth/#{surface}/sign/outs/completions", "show")
      assert_recognizes_sign_route(surface, "/sign/out", :post, "auth/#{surface}/sign/outs", "create")
      assert_recognizes_sign_route(surface, "/sign/out", :delete, "auth/#{surface}/sign/outs", "destroy")
      assert_unrecognized(surface, "/signed-out", :get)
      assert_recognizes_sign_route(
        surface, "/oidc/backchannel/logout", :post,
        "auth/#{surface}/oidc/backchannel/logouts", "create",
      )
      assert_unrecognized(surface, "/oidc/frontchannel_logout", :get)
      assert_unrecognized(surface, "/oidc/logout", :get)
      assert_unrecognized(surface, "/oidc/logout", :post)
      assert_unrecognized(surface, "/sign/out/confirmation", :get)
      assert_unrecognized(surface, "/sign/out/attempt", :post)
      assert_unrecognized(surface, "/sign/out/completion", :get)
    end
  end

  test "sign check routes use checks controller namespace and old checkpoint route is absent" do
    assert_recognizes_sign_route(:app, "/sign/in/check", :get, "auth/app/sign/in/checks", "show")
    assert_recognizes_sign_route(:app, "/sign/in/check", :patch, "auth/app/sign/in/checks", "update")
    assert_recognizes_sign_route(:app, "/sign/in/check", :delete, "auth/app/sign/in/checks", "destroy")
    assert_recognizes_sign_route(:com, "/sign/in/check", :get, "auth/com/sign/in/checks", "show")
    assert_recognizes_sign_route(:com, "/sign/in/check", :delete, "auth/com/sign/in/checks", "destroy")
    assert_recognizes_sign_route(:org, "/sign/in/check", :get, "auth/org/sign/in/checks", "show")
    assert_recognizes_sign_route(:org, "/sign/in/check", :delete, "auth/org/sign/in/checks", "destroy")

    SURFACES.each_key do |surface|
      assert_unrecognized(surface, "/sign/in/checkpoint", :get)
      assert_unrecognized(surface, "/sign/in/checkpoint", :patch)
      assert_unrecognized(surface, "/sign/in/checkpoint", :delete)
    end
  end

  test "com org social routes remain absent from sign authority surfaces" do
    assert_unrecognized(:com, "/social/apple/connection", :get)
    assert_unrecognized(:org, "/social/google/connection", :get)
  end

  test "preference routes are not exposed on sign" do
    assert_unrecognized(:app, "/preference/language/edit", :get)
  end

  test "settings mfa reset resolves through conventional settings mfa namespace" do
    assert_recognizes_sign_route(:app, "/settings/mfa/reset", :get, "auth/app/settings/mfa/resets", "show")
    assert_recognizes_sign_route(:app, "/settings/mfa/reset", :post, "auth/app/settings/mfa/resets", "create")
  end

  test "session revocation uses post routes instead of collection deletes" do
    assert_recognizes_sign_route(
      :app, "/settings/sessions/abc/revocation", :post,
      "auth/app/settings/revocations", "create",
    )
    assert_recognizes_sign_route(
      :app, "/settings/revocations/others", :post,
      "auth/app/settings/revocations/others", "create",
    )
    assert_recognizes_sign_route(
      :app, "/settings/revocations/all", :post,
      "auth/app/settings/revocations/alls", "create",
    )

    assert_unrecognized(:app, "/settings/sessions/abc/revocation_attempt", :post)
    assert_unrecognized(:app, "/settings/session_revocations/others", :post)
    assert_unrecognized(:app, "/settings/sessions/others", :delete)
    assert_unrecognized(:app, "/settings/sessions/revoke_all", :delete)
  end

  test "route source excludes sign routing compatibility patterns" do
    source = Rails.root.join("config/routes/auth.rb").read

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
    ]

    forbidden.each do |pattern|
      assert_not_includes source, pattern, pattern
    end

    assert_includes source, "scope(module: :auth, as: :auth)"
    assert_includes source, "constraints("
    assert_includes source, "namespace(:oidc)"
    assert_includes source, "namespace(:social)"
  end

  private

  def assert_recognizes_sign_route(surface, path, method, controller, action)
    host = SURFACES.fetch(surface)
    route = Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)

    assert_equal controller, route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_unrecognized(surface, path, method)
    host = SURFACES.fetch(surface)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
    end
  end
end
