# typed: false
# frozen_string_literal: true

require "test_helper"

module Core
  class CookieDomainTest < ActiveSupport::TestCase
    test "normalizes app.localhost credential to .app.localhost" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: "app.localhost") do
        assert_equal ".app.localhost", Core::CookieDomain.for(surface: :app, request_host: "app.localhost")
      end
    end

    test "normalizes example.com credential to .example.com for non-localhost host" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: "example.com") do
        assert_equal ".example.com", Core::CookieDomain.for(surface: :app, request_host: "app.example.com")
      end
    end

    test "ignores production credential when request host is localhost" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".example.com") do
        assert_equal ".app.localhost", Core::CookieDomain.for(surface: :app, request_host: "app.localhost")
      end
    end

    test "keeps dotted credential as is for non-localhost host" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: ".example.com") do
        assert_equal ".example.com", Core::CookieDomain.for(surface: :app, request_host: "app.example.com")
      end
    end

    test "returns host-only when credential is HOST_ONLY" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: "HOST_ONLY") do
        assert_nil Core::CookieDomain.for(surface: :app, request_host: "app.example.com")
      end
    end

    test "derives .app.localhost when credential blank and host is app.localhost" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: nil) do
        assert_equal ".app.localhost", Core::CookieDomain.for(surface: :app, request_host: "app.localhost")
      end
    end

    test "derives .app.localhost for nested localhost hosts" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: nil) do
        assert_equal ".app.localhost", Core::CookieDomain.for(surface: :app, request_host: "id.app.localhost")
      end
    end

    test "derives .example.com when credential blank and host is app.example.com" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: nil) do
        assert_equal ".example.com", Core::CookieDomain.for(surface: :app, request_host: "app.example.com")
      end
    end

    test "returns nil when host is localhost" do
      with_cookie_domain_credentials(COOKIE_DOMAIN_APP: nil) do
        assert_nil Core::CookieDomain.for(surface: :app, request_host: "localhost")
      end
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
end
