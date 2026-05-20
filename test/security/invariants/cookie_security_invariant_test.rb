# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class CookieSecurityInvariantTest < ActiveSupport::TestCase
      fixtures_none!

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      RecordingCookies =
        Struct.new(:writes) do
          delegate :[]=, to: :writes
        end

      Request =
        Struct.new(:host) do
          def ssl? = false
        end

      test "production auth cookie names use host prefix" do
        assert_equal "__Host-auth_access", Authentication::CookieName.access(production: true)
        assert_equal "__Host-auth_refresh", Authentication::CookieName.refresh(production: true)
        assert_equal "__Host-auth_device_id", Authentication::CookieName.device(production: true)
      end

      test "auth refresh and device cookies use secure host-prefix compatible attributes" do
        cookies = RecordingCookies.new({})
        request = Request.new("id.app.example")

        with_force_secure_cookies do
          Authentication::CookieService.new(cookies, request).set_auth_cookies(
            access_token: "access-token",
            refresh_token: "refresh-token",
            device_id: "device-id",
            access_ttl: 15.minutes,
            refresh_ttl: 30.days,
          )
        end

        assert_auth_cookie_options(cookies.writes.fetch(Authentication::CookieName.access))
        assert_auth_cookie_options(cookies.writes.fetch(Authentication::CookieName.refresh))
        assert_auth_cookie_options(cookies.writes.fetch(Authentication::CookieName.device))
      end

      test "production session cookie is secure httponly lax and host-prefixed" do
        assert SessionCookieConfig.force_secure?(
          id_service_host: "id.app.example",
          rails_env: ActiveSupport::StringInquirer.new("production"),
        )
        assert_equal "__Host-session", SessionCookieConfig.cookie_key(force_secure: true)
        assert SessionCookieConfig.partitioned?(rails_env: ActiveSupport::StringInquirer.new("production"))

        session_options = Rails.application.config.session_options

        assert session_options[:httponly]
        assert_equal :lax, session_options[:same_site]
      end

      private

      def assert_auth_cookie_options(options)
        assert options[:secure]
        assert options[:httponly]
        assert_equal :lax, options[:same_site]
        assert_equal "/", options[:path]
        assert_not options.key?(:domain), "__Host- cookies must not carry a Domain attribute"
      end

      def with_force_secure_cookies
        previous = ENV["FORCE_SECURE_COOKIES"]
        ENV["FORCE_SECURE_COOKIES"] = "1"
        yield
      ensure
        ENV["FORCE_SECURE_COOKIES"] = previous
      end
    end
  end
end
