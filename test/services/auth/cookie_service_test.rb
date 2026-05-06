# typed: false
# frozen_string_literal: true

require "test_helper"

class CookieServiceTest < ActiveSupport::TestCase
  class MockRequest
    attr_accessor :headers, :url, :host

    def initialize
      @headers = {}
      @url = "https://app.example.com/"
      @host = "app.example.com"
    end

    def ssl?
      true
    end
  end

  class MockCookies
    attr_accessor :cookies_hash

    def initialize
      @cookies_hash = {}
    end

    delegate :[], to: :@cookies_hash

    delegate :[]=, to: :@cookies_hash

    def delete(key, *)
      @cookies_hash.delete(key)
    end

    def encrypted
      self
    end
  end

  test "access_cookie_key returns access cookie name" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    assert_equal "auth_access", service.access_cookie_key
  end

  test "refresh_cookie_key returns refresh cookie name" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    assert_equal "auth_refresh", service.refresh_cookie_key
  end

  test "device_cookie_key returns device cookie name" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    assert_equal "auth_device_id", service.device_cookie_key
  end

  test "read_device_id_cookie returns device id" do
    cookies = MockCookies.new
    cookies.cookies_hash["auth_device_id"] = "device_456"
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    result = service.read_device_id_cookie

    assert_equal "device_456", result
  end

  test "read_device_id_cookie returns nil when not present" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    result = service.read_device_id_cookie

    assert_nil result
  end

  test "extract_access_token_from_request returns token from authorization header" do
    cookies = MockCookies.new
    request = MockRequest.new
    request.headers["Authorization"] = "Bearer abc123token"
    service = Auth::CookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "abc123token", result
  end

  test "extract_access_token_from_request accepts lowercase bearer scheme" do
    cookies = MockCookies.new
    request = MockRequest.new
    request.headers["Authorization"] = "bearer abc123token"
    service = Auth::CookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "abc123token", result
  end

  test "extract_access_token_from_request returns nil for invalid prefix" do
    cookies = MockCookies.new
    request = MockRequest.new
    request.headers["Authorization"] = "Basic abc123token"
    service = Auth::CookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_nil result
  end

  test "extract_access_token_from_request falls back to cookie" do
    cookies = MockCookies.new
    cookies.cookies_hash["auth_access"] = "cookie_token"
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "cookie_token", result
  end

  test "extract_access_token_from_request returns nil when no token present" do
    cookies = MockCookies.new
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_nil result
  end

  test "extract_access_token_from_request prefers bearer token over cookie" do
    cookies = MockCookies.new
    cookies.cookies_hash["auth_access"] = "cookie_token"
    request = MockRequest.new
    request.headers["Authorization"] = "Bearer bearer_token"
    service = Auth::CookieService.new(cookies, request)

    result = service.extract_access_token_from_request

    assert_equal "bearer_token", result
  end

  test "read_device_id_cookie returns empty string coerced to nil" do
    cookies = MockCookies.new
    cookies.cookies_hash["auth_device_id"] = ""
    request = MockRequest.new
    service = Auth::CookieService.new(cookies, request)

    result = service.read_device_id_cookie

    assert_nil result
  end
end
