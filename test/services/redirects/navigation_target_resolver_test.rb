# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RedirectsNavigationTargetResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def auth_app_sign_in_check_path(ri:) = "/sign/in/check?ri=#{ri}"

      def auth_app_sign_in_path(ri:) = "/sign/in?ri=#{ri}"

      def acme_app_dashboard_path(ri:) = "/dashboard?ri=#{ri}"

      def auth_app_settings_path(ri:) = "/settings?ri=#{ri}"
    end

  test "resolves registered navigation keys" do
    assert_equal "/sign/in/check?ri=jp", resolve(:checkpoint).value
    assert_equal "/sign/in?ri=jp", resolve(:selector).value
    assert_equal "/dashboard?ri=jp", resolve(:dashboard).value
    assert_equal "/settings?ri=jp", resolve(:settings_security, scope: :settings).value
  end

  test "rejects unknown raw url and raw path keys" do
    assert_not resolve(:missing).ok?
    assert_not resolve("https://evil.example").ok?
    assert_not resolve("/dashboard").ok?
  end

  test "enforces flow scope" do
    result = resolve(:settings_security, scope: :authentication)

    assert_not result.ok?
    assert_equal "scope_denied", result.failure_reason
  end

  test "resolves signed out and home targets with default app surface" do
    signed_out = resolve(:signed_out, params: { ri: "jp" })
    home = resolve(:home, params: { ri: "jp" })
    string_key = RedirectsNavigationTargetResolver.call(
      "dashboard",
      routes: Routes.new,
      params: { ri: "jp", surface: "app" },
      source: :test,
    )

    assert_predicate signed_out, :ok?
    assert_equal "/sign/out?ri=jp", signed_out.value

    assert_predicate home, :ok?
    assert_equal "/?ri=jp", home.value

    assert_predicate string_key, :ok?
    assert_equal "/dashboard?ri=jp", string_key.value
  end

  test "does not resolve external urls from registry" do
    routes = Class.new do
      def acme_app_dashboard_path(**) = "https://evil.example"
    end.new
    result = RedirectsNavigationTargetResolver.call(
      :dashboard,
      routes: routes,
      params: { ri: "jp", surface: "app" },
      source: :test,
    )

    assert_not result.ok?
    assert_equal "invalid_registered_path", result.failure_reason
  end

  private

  def resolve(key, scope: nil, params: { ri: "jp", surface: "app" })
    RedirectsNavigationTargetResolver.call(
      key,
      routes: Routes.new,
      params: params,
      scope: scope,
      source: :test,
    )
  end
end
