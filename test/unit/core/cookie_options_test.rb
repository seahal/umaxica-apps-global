# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreCookieOptionsTest < ActiveSupport::TestCase
  class MockRequest
    attr_reader :host, :ssl

    def initialize(host, ssl: false)
      @host = host
      @ssl = ssl
    end

    def ssl?
      @ssl
    end
  end

  test "for returns httponly and secure options" do
    request = MockRequest.new("wwww.example.com")
    surface = :app

    options = Core::CookieOptions.for(surface: surface, request: request, secure: true)

    assert options[:httponly]
    assert options[:secure]
  end

  test "for includes same_site when provided" do
    request = MockRequest.new("wwww.example.com")
    surface = :app

    options = Core::CookieOptions.for(surface: surface, request: request, same_site: :strict)

    assert_equal :strict, options[:same_site]
  end

  test "for includes expires when provided" do
    request = MockRequest.new("wwww.example.com")
    surface = :app
    expires = 1.hour.from_now

    options = Core::CookieOptions.for(surface: surface, request: request, expires: expires)

    assert_equal expires, options[:expires]
  end

  test "for includes path when provided" do
    request = MockRequest.new("wwww.example.com")
    surface = :app

    options = Core::CookieOptions.for(surface: surface, request: request, path: "/api")

    assert_equal "/api", options[:path]
  end

  test "for includes domain when surface has domain" do
    request = MockRequest.new("wwww.example.com")
    surface = :app

    with_cookie_domain_credentials(COOKIE_DOMAIN_APP: "example.com") do
      options = Core::CookieOptions.for(surface: surface, request: request, domain: true)

      assert_equal ".example.com", options[:domain]
    end
  end

  test "for omits domain when disabled" do
    request = MockRequest.new("wwww.example.com")
    surface = :app

    options = Core::CookieOptions.for(surface: surface, request: request, domain: false)

    assert_not options.key?(:domain)
  end

  test "for includes same_site lax when provided" do
    request = MockRequest.new("wwww.example.com")

    options = Core::CookieOptions.for(surface: :app, request: request, same_site: :lax)

    assert_equal :lax, options[:same_site]
  end

  test "for includes expires one year when provided" do
    request = MockRequest.new("wwww.example.com")
    expires = 1.year.from_now

    options = Core::CookieOptions.for(surface: :app, request: request, expires: expires)

    assert_equal expires, options[:expires]
  end

  test "for includes path accounts when provided" do
    request = MockRequest.new("wwww.example.com")

    options = Core::CookieOptions.for(surface: :app, request: request, path: "/accounts")

    assert_equal "/accounts", options[:path]
  end

  test "for includes domain when surface has domain without mocking" do
    request = MockRequest.new("wwww.example.com")

    options = Core::CookieOptions.for(surface: :app, request: request)

    assert_predicate options[:domain], :present? if options[:domain]
  end

  private

  def with_cookie_domain_credentials(overrides)
    creds = Rails.app.creds
    fetch = ->(key, default: nil) { overrides.fetch(key, default) }

    creds.stub(:option, fetch) do
      yield
    end
  end
end
