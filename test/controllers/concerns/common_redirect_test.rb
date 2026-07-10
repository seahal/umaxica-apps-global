# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CommonRedirectTest < ActiveSupport::TestCase
  # normalize_host is a pure class method -- no controller context required.

  test "normalize_host returns nil for blank input" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
    assert_nil CommonRedirect.normalize_host("   ")
  end

  test "normalize_host extracts host from a full URL" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com/path?q=1")
    assert_equal "example.com", CommonRedirect.normalize_host("http://example.com")
  end

  test "normalize_host returns a downcased plain hostname" do
    assert_equal "example.com", CommonRedirect.normalize_host("Example.COM")
  end

  test "normalize_host strips scheme remnants from bare host strings" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com")
    assert_equal "example.com", CommonRedirect.normalize_host("http://example.com")
  end

  test "normalize_host handles port-included URLs by returning just the host" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com:443/path")
  end

  test "normalize_host handles URIs with an invalid scheme by using the raw string" do
    result = CommonRedirect.normalize_host("not a uri\x00invalid")

    assert_not_nil result
  end

  test "normalize_host strips leading path components from plain path strings" do
    # A path-only string has no URI host; falls back to splitting on '/'
    result = CommonRedirect.normalize_host("example.com/some/path")

    assert_equal "example.com", result
  end
end
