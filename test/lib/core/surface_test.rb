# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreSurfaceTest < ActiveSupport::TestCase
  class MockRequest
    attr_accessor :host

    def initialize(host)
      @host = host
    end
  end

  test "detect returns app for app subdomain" do
    request = MockRequest.new("app.example.com")

    assert_equal :app, CoreSurface.detect(request)
  end

  test "detect returns com for com subdomain" do
    request = MockRequest.new("example.com")

    assert_equal :com, CoreSurface.detect(request)
  end

  test "detect returns org for org subdomain" do
    request = MockRequest.new("org.example.com")

    assert_equal :org, CoreSurface.detect(request)
  end

  test "detect returns net for net subdomain" do
    request = MockRequest.new("net.example.com")

    assert_equal :net, CoreSurface.detect(request)
  end

  test "detect returns dev for dev subdomain" do
    request = MockRequest.new("dev.example.com")

    assert_equal :dev, CoreSurface.detect(request)
  end

  test "detect returns DEFAULT for unknown host" do
    request = MockRequest.new("unknown.example.com")

    assert_equal :com, CoreSurface.detect(request)
  end

  test "detect returns DEFAULT for blank host" do
    request = MockRequest.new("")

    assert_equal :com, CoreSurface.detect(request)
  end

  test "detect returns DEFAULT for nil host" do
    request = MockRequest.new(nil)

    assert_equal :com, CoreSurface.detect(request)
  end

  test "detect returns app for deeply nested app subdomain" do
    request = MockRequest.new("deep.app.nested.example.com")

    assert_equal :app, CoreSurface.detect(request)
  end

  test "detect is case insensitive" do
    request = MockRequest.new("APP.EXAMPLE.COM")

    assert_equal :app, CoreSurface.detect(request)
  end

  test "detect handles host with port" do
    request = MockRequest.new("app.example.com:3000")

    assert_equal :app, CoreSurface.detect(request)
  end

  test "current delegates to detect" do
    request = MockRequest.new("app.example.com")

    assert_equal :app, CoreSurface.current(request)
  end

  test "matches returns true when surface matches" do
    request = MockRequest.new("app.example.com")

    assert CoreSurface.matches?(request, :app)
  end

  test "matches returns false when surface does not match" do
    request = MockRequest.new("app.example.com")

    assert_not CoreSurface.matches?(request, :org)
  end

  test "normalized_host lowercases and removes trailing dot" do
    assert_equal "example.com", CoreSurface.send(:normalized_host, "EXAMPLE.COM")
    assert_equal "example.com", CoreSurface.send(:normalized_host, "example.com.")
  end

  test "normalized_host removes port" do
    assert_equal "example.com", CoreSurface.send(:normalized_host, "example.com:8080")
  end

  test "normalized_host extracts host from a URL string" do
    assert_equal "app.example.com", CoreSurface.send(:normalized_host, "https://APP.EXAMPLE.COM:3000/path")
  end

  test "normalized_host returns nil for blank" do
    assert_nil CoreSurface.send(:normalized_host, "")
    assert_nil CoreSurface.send(:normalized_host, nil)
  end

  test "extract_host returns host if request responds to host" do
    request = MockRequest.new("app.example.com")

    assert_equal "app.example.com", CoreSurface.send(:extract_host, request)
  end

  test "extract_host converts string to host" do
    assert_equal "app.example.com", CoreSurface.send(:extract_host, "app.example.com")
  end
end
