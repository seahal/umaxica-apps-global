# frozen_string_literal: true

require "test_helper"

class RedirectsPriorityResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def auth_app_sign_in_check_path(ri:) = "/sign/in/check?ri=#{ri}"

      def auth_app_sign_in_path(ri:) = "/sign/in?ri=#{ri}"

      def acme_app_dashboard_path(ri:) = "/dashboard?ri=#{ri}"

      def auth_app_settings_path(ri:) = "/settings?ri=#{ri}"
    end

  test "explicit nt wins over signed pt" do
    result = resolve([{ kind: :nt, value: :dashboard }, { kind: :signed_pt, value: "/settings" }])

    assert_equal "/dashboard?ri=jp", result.value
  end

  test "signed nt wins over raw pt" do
    result = resolve([{ kind: :signed_nt, value: :checkpoint }, { kind: :pt, value: "/settings" }])

    assert_equal "/sign/in/check?ri=jp", result.value
  end

  test "signed pt wins over raw pt" do
    result = resolve([{ kind: :signed_pt, value: "/dashboard" }, { kind: :pt, value: "/settings" }])

    assert_equal "/dashboard", result.value
  end

  test "raw pt is used only when safe" do
    assert_equal "/settings", resolve([{ kind: :pt, value: "/settings" }]).value
    assert_not resolve([{ kind: :pt, value: "https://evil.example" }]).ok?
  end

  test "external is not part of internal priority chain" do
    result = resolve([{ kind: :external, value: :rp_app }, { kind: :pt, value: "/settings" }])

    assert_equal "/settings", result.value
  end

  test "default path is final explicit fallback" do
    assert_equal "/default", resolve([{ kind: :pt, value: "" }], default: "/default").value
  end

  private

  def resolve(priority, default: "/default")
    RedirectsPriorityResolver.call(
      priority: priority,
      routes: Routes.new,
      params: { ri: "jp", surface: "app" },
      default: default,
    )
  end
end
