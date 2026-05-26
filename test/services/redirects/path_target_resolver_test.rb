# frozen_string_literal: true

require "test_helper"

class Redirects::PathTargetResolverTest < ActiveSupport::TestCase
  test "allows path only targets" do
    assert_equal "/dashboard", resolve("/dashboard").value
    assert_equal "/dashboard?tab=security", resolve("/dashboard?tab=security").value
    assert_equal "/configuration/security", resolve("/configuration/security").value
    assert_equal "/sign/out/complete?x=1", resolve("/sign/out/complete?x=1").value
  end

  test "rejects external and escaped host targets" do
    [
      "https://evil.example",
      "http://evil.example",
      "//evil.example",
      "/\\evil.example",
      "\\evil.example",
      "/%2fevil.example",
      "/%5cevil.example",
    ].each do |value|
      assert_not resolve(value).ok?, value
    end
  end

  test "rejects executable schemes and injection characters" do
    [
      "javascript:alert(1)",
      "data:text/html,boom",
      "/%0d%0aLocation:%20https://evil.example",
      "/dashboard\nLocation: https://evil.example",
      "/dashboard\u0000",
    ].each do |value|
      assert_not resolve(value).ok?, value
    end
  end

  test "rejects scheme host userinfo blank and nil with reason" do
    ["https://user:pass@evil.example/path", "", nil].each do |value|
      result = resolve(value)

      assert_not result.ok?
      assert_predicate result.failure_reason, :present?
      assert_nil result.value
    end
  end

  private

  def resolve(value)
    Redirects::PathTargetResolver.call(value, source: :test)
  end
end
