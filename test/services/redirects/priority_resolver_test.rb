# frozen_string_literal: true

require "test_helper"

class Redirects::PriorityResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def sign_app_in_checkpoint_path(ri:) = "/sign/in/checkpoint?ri=#{ri}"

      def sign_app_in_path(ri:) = "/sign/in?ri=#{ri}"

      def sign_app_dashboard_path(ri:) = "/dashboard?ri=#{ri}"

      def sign_app_configuration_path(ri:) = "/configuration?ri=#{ri}"
    end

  test "explicit nt wins over signed pt" do
    result = resolve([{ kind: :nt, value: :dashboard }, { kind: :signed_pt, value: "/configuration" }])

    assert_equal "/dashboard?ri=jp", result.value
  end

  test "signed nt wins over raw pt" do
    result = resolve([{ kind: :signed_nt, value: :checkpoint }, { kind: :pt, value: "/configuration" }])

    assert_equal "/sign/in/checkpoint?ri=jp", result.value
  end

  test "signed pt wins over raw pt" do
    result = resolve([{ kind: :signed_pt, value: "/dashboard" }, { kind: :pt, value: "/configuration" }])

    assert_equal "/dashboard", result.value
  end

  test "raw pt is used only when safe" do
    assert_equal "/configuration", resolve([{ kind: :pt, value: "/configuration" }]).value
    assert_not resolve([{ kind: :pt, value: "https://evil.example" }]).ok?
  end

  test "external is not part of internal priority chain" do
    result = resolve([{ kind: :external, value: :rp_app }, { kind: :pt, value: "/configuration" }])

    assert_equal "/configuration", result.value
  end

  test "default path is final explicit fallback" do
    assert_equal "/default", resolve([{ kind: :pt, value: "" }], default: "/default").value
  end

  private

  def resolve(priority, default: "/default")
    Redirects::PriorityResolver.call(
      priority: priority,
      routes: Routes.new,
      params: { ri: "jp", surface: "app" },
      default: default,
    )
  end
end
