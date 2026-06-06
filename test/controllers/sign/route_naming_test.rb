# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::RouteNamingTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    com: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
    org: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
  }.freeze

  test "sign entrance and sign out helpers use explicit lifecycle resources" do
    assert_equal "/sign/up/entrance", sign_app_sign_up_entrance_path
    assert_equal "/sign/in/entrance", sign_app_sign_in_entrance_path
    assert_equal "/sign/out/confirmation", sign_app_sign_out_confirmation_path
    assert_equal "/sign/out/attempt", sign_app_sign_out_attempt_path
    assert_equal "/sign/out/completion", sign_app_sign_out_completion_path
  end

  test "old top-level sign helper aliases are gone" do
    helpers = Rails.application.routes.url_helpers

    assert_not_respond_to helpers, :new_sign_app_sign_in_path
    assert_not_respond_to helpers, :new_sign_app_sign_up_path
    assert_not_respond_to helpers, :sign_app_sign_out_path
    assert_not_respond_to helpers, :edit_sign_app_sign_out_path
  end

  test "top-level sign lifecycle routes resolve conventionally on every sign surface" do
    SURFACES.each_key do |surface|
      assert_recognizes_sign_route(surface, "/sign/up/entrance", :get, "sign/up/entrances", "show")
      assert_recognizes_sign_route(surface, "/sign/in/entrance", :get, "sign/in/entrances", "show")
      assert_recognizes_sign_route(surface, "/sign/out/confirmation", :get, "sign/out/confirmations", "show")
      assert_recognizes_sign_route(surface, "/sign/out/attempt", :post, "sign/out/attempts", "create")
      assert_recognizes_sign_route(surface, "/sign/out/completion", :get, "sign/out/completions", "show")
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
    assert_recognizes_sign_route(:app, "/social/apple/connection", :get, "social/apple/connections", "show")
    assert_recognizes_sign_route(
      :app, "/social/apple/connection_attempt", :post,
      "social/apple/connection_attempts", "create",
    )
    assert_recognizes_sign_route(
      :app, "/social/google/disconnection_attempt", :post,
      "social/google/disconnection_attempts", "create",
    )

    assert_unrecognized(:app, "/social/auth/apple", :delete)
    assert_unrecognized(:app, "/social/auth/apple/continue", :post)
    assert_unrecognized(:com, "/social/apple/connection", :get)
    assert_unrecognized(:org, "/social/google/connection", :get)
  end

  test "preference routes do not carry preference screen defaults" do
    route = Rails.application.routes.recognize_path(
      "https://#{SURFACES.fetch(:app)}/preference/language/edit",
      method: :get,
    )

    assert_equal "sign/app/preference/languages", route.fetch(:controller)
    assert_not route.key?(:preference_screen)
  end

  test "settings mfa reset resolves through conventional settings mfa namespace" do
    assert_recognizes_sign_route(:app, "/settings/mfa/reset", :get, "settings/mfa/resets", "show")
    assert_recognizes_sign_route(:app, "/settings/mfa/reset", :post, "settings/mfa/resets", "create")
  end

  test "session revocation uses post attempt routes instead of collection deletes" do
    assert_recognizes_sign_route(
      :app, "/settings/sessions/abc/revocation_attempt", :post,
      "settings/revocation_attempts", "create",
    )
    assert_recognizes_sign_route(
      :app, "/settings/session_revocations/others", :post,
      "settings/session_revocations/others", "create",
    )
    assert_recognizes_sign_route(
      :app, "/settings/session_revocations/all", :post,
      "settings/session_revocations/alls", "create",
    )

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
