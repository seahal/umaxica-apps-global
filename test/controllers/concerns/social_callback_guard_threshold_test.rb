# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdSocialGuardTest < ActiveSupport::TestCase
  test "social callback normalization and method allowlists cover invalid forms" do
    assert_nil SocialCallbackGuard.normalize_host_port(nil)
    assert_nil SocialCallbackGuard.normalize_host_port("http://[bad")
    assert_equal "example.com", SocialCallbackGuard.normalize_host_port("HTTPS://EXAMPLE.COM")
    assert_equal "example.com:8443", SocialCallbackGuard.normalize_host_port("https://example.com:8443")
    assert_equal "example.com:8080", SocialCallbackGuard.normalize_host_port("example.com:8080")
    assert_nil SocialCallbackGuard.normalize_origin("ftp://example.com")
    assert_nil SocialCallbackGuard.normalize_origin("not uri")
    assert_equal "https://example.com:8443", SocialCallbackGuard.normalize_origin("HTTPS://EXAMPLE.COM:8443/path")
    assert SocialCallbackGuard.allowed_request_method?("google", "POST")
    assert_not SocialCallbackGuard.allowed_request_method?("google", "GET")
    assert_not SocialCallbackGuard.allowed_request_method?("unknown", "POST")
    assert SocialCallbackGuard.allowed_callback_method?("apple", "GET")
    assert_not SocialCallbackGuard.allowed_callback_method?("apple", "POST")
    assert_not SocialCallbackGuard.allowed_callback_method?("unknown", "GET")
  end
end
