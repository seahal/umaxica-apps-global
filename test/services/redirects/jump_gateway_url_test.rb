# typed: false
# frozen_string_literal: true

require "test_helper"

class Redirects::JumpGatewayUrlTest < ActiveSupport::TestCase
  test "builds jump gateway url with rt query" do
    with_env("JUMP_GATEWAY_URL" => "https://jump.umaxica.net") do
      result = Redirects::JumpGatewayUrl.call("aaa.bbb.ccc")

      assert_predicate result, :ok?
      assert_equal "https://jump.umaxica.net/?rt=aaa.bbb.ccc", result.value
    end
  end

  test "rejects malformed tokens" do
    assert_not Redirects::JumpGatewayUrl.call("aaa.bbb").ok?
    assert_not Redirects::JumpGatewayUrl.call("aaa.bbb.ccc=").ok?
    assert_not Redirects::JumpGatewayUrl.call("aaa.bbb.ccc\n").ok?
  end

  test "rejects unsafe gateway origins" do
    with_env("JUMP_GATEWAY_URL" => "http://jump.example") do
      result = Redirects::JumpGatewayUrl.call("aaa.bbb.ccc")

      assert_not result.ok?
      assert_equal "https_required", result.failure_reason
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
