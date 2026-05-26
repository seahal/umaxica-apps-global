# frozen_string_literal: true

require "test_helper"

class Redirects::ExternalTargetResolverTest < ActiveSupport::TestCase
  test "resolves allowlisted external key" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = Redirects::ExternalTargetResolver.call(:rp_app, path: "/signed-out", query: { ok: "1" })

      assert_predicate result, :ok?
      assert_equal "https://rp.example/signed-out?ok=1", result.value
    end
  end

  test "rejects unknown allowlist key" do
    assert_not Redirects::ExternalTargetResolver.call(:evil, path: "/").ok?
  end

  test "rejects http downgrade except local development origins" do
    with_env("RP_APP_URL" => "http://evil.example") do
      result = Redirects::ExternalTargetResolver.call(:rp_app, path: "/signed-out")

      assert_not result.ok?
      assert_equal "https_required", result.failure_reason
    end
  end

  test "path join cannot escape to another host" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = Redirects::ExternalTargetResolver.call(:rp_app, path: "//evil.example")

      assert_not result.ok?
    end
  end

  test "query merge strips dangerous redirect parameters" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = Redirects::ExternalTargetResolver.call(
        :rp_app,
        path: "/signed-out?pt=/safe",
        query: { "redirect_uri" => "https://evil.example", "nt" => "dashboard", "ok" => "1" },
      )

      assert_predicate result, :ok?
      assert_equal "https://rp.example/signed-out?ok=1", result.value
    end
  end

  private

  def with_env(values)
    previous = values.transform_values { |_value| nil }
    values.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
