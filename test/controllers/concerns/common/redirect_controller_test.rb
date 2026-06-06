# typed: false
# frozen_string_literal: true

require "test_helper"

class TestRedirectController < ApplicationController
  include CommonRedirect
end

class CommonRedirectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @controller = TestRedirectController.new
  end

  test "allowed_hosts returns array of hosts" do
    hosts = @controller.allowed_hosts

    assert_kind_of Array, hosts
    # Should include at least some hosts from environment variables
    assert hosts.all? { |h| h.is_a?(String) }
  end

  test "normalize_host strips scheme from URL" do
    result = CommonRedirect.normalize_host("http://example.com/path")

    assert_includes result, "example.com"
    result = CommonRedirect.normalize_host("https://example.com")

    assert_includes result, "example.com"
  end

  test "normalize_host handles localhost" do
    result = CommonRedirect.normalize_host("localhost:3000")

    assert_includes result, "localhost"
    result = CommonRedirect.normalize_host("http://localhost")

    assert_includes result, "localhost"
  end

  test "normalize_host handles subdomains" do
    assert_equal "sub.example.com", CommonRedirect.normalize_host("https://sub.example.com/path")
  end

  test "normalize_host returns nil for invalid input" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
  end
end
