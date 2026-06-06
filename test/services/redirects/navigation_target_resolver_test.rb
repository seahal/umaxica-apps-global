# frozen_string_literal: true

require "test_helper"

class RedirectsNavigationTargetResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def sign_app_in_check_path(ri:) = "/sign/in/check?ri=#{ri}"

      def sign_app_in_path(ri:) = "/sign/in?ri=#{ri}"

      def acme_app_dashboard_path(ri:) = "/dashboard?ri=#{ri}"

      def sign_app_settings_path(ri:) = "/settings?ri=#{ri}"
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

  def resolve(key, scope: nil)
    RedirectsNavigationTargetResolver.call(
      key,
      routes: Routes.new,
      params: { ri: "jp", surface: "app" },
      scope: scope,
      source: :test,
    )
  end
end
