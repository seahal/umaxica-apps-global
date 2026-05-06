# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class BaseTest < ActiveSupport::TestCase
    class HeaderKeyHarness
      class MockCookies
        delegate :[], to: :@store

        def initialize(store)
          @store = store
        end

        def []=(key, value)
          @store[key] = value
          HeaderKeyHarness.encrypted_cookies[key] = value
        end

        def delete(key, _options = nil)
          @store.delete(key)
        end

        def encrypted
          HeaderKeyHarness.encrypted_cookies
        end
      end

      include Authentication::Base

      attr_accessor :actor_type
      attr_writer :logged_in

      def resource_type
        actor_type
      end

      def resource_class = User

      def token_class = UserToken

      def audit_class = UserChronicle

      def resource_foreign_key = :user_id

      def sign_in_url_with_return(_return_to) = "/sign/in"

      def am_i_user? = false

      def am_i_staff? = false

      def am_i_owner? = false

      def initialize
        @params_hash = {}
        @session_hash = {}
        @flash_hash = {}
        @logged_in = false
        @request_stub = Struct.new(:format, :host, :request_id, :remote_ip).new(
          Struct.new(:json?).new(false),
          "app.localhost", "req-123", "127.0.0.1",
        )
        @cookies = MockCookies.new(self.class.encrypted_cookies)
      end

      def cookies
        @cookies
      end

      def self.encrypted_cookies
        Thread.current[:auth_base_test_encrypted_cookies] ||= {}.with_indifferent_access
      end

      def self.reset_encrypted_cookies!
        Thread.current[:auth_base_test_encrypted_cookies] = {}.with_indifferent_access
      end

      def current_resource
        @logged_in ? Object.new : nil
      end

      def params
        @params_hash.with_indifferent_access
      end

      def params=(value)
        @params_hash = value
      end

      def session
        @session_hash
      end

      def flash
        @flash_hash
      end

      def request
        @request_stub
      end

      def json_request!
        @request_stub = Struct.new(:format).new(Struct.new(:json?).new(true))
      end

      def html_request!
        @request_stub = Struct.new(:format).new(Struct.new(:json?).new(false))
      end

      def render(**kwargs)
        @rendered = kwargs
      end

      def rendered
        @rendered
      end

      def redirect_to(path, **kwargs)
        @redirected = [path, kwargs]
      end

      def redirected
        @redirected
      end

      def jump_to_generated_url(url, fallback:)
        @jumped = [url, fallback]
      end

      def jumped
        @jumped
      end

      def t(key)
        "translated:#{key}"
      end
    end

    test "VALID_POLICIES constant is defined" do
      assert_equal %i(public_strict auth_required guest_only), Authentication::Base::VALID_POLICIES
    end

    test "AUDIT_EVENTS constant is defined" do
      assert Authentication::Base::AUDIT_EVENTS.key?(:logged_in)
      assert Authentication::Base::AUDIT_EVENTS.key?(:logged_out)
      assert Authentication::Base::AUDIT_EVENTS.key?(:login_failed)
      assert Authentication::Base::AUDIT_EVENTS.key?(:token_refreshed)
    end

    test "ACCESS_COOKIE_KEY is defined" do
      assert_kind_of String, Authentication::Base::ACCESS_COOKIE_KEY
      assert_equal "auth_access", Authentication::Base::ACCESS_COOKIE_KEY
    end

    test "REFRESH_COOKIE_KEY is defined" do
      assert_kind_of String, Authentication::Base::REFRESH_COOKIE_KEY
      assert_equal "auth_refresh", Authentication::Base::REFRESH_COOKIE_KEY
    end

    test "DEVICE_COOKIE_KEY is defined" do
      assert_kind_of String, Authentication::Base::DEVICE_COOKIE_KEY
      assert_equal "auth_device_id", Authentication::Base::DEVICE_COOKIE_KEY
    end

    test "test_header_key resolves actor specific keys" do
      harness = HeaderKeyHarness.new

      harness.actor_type = "user"

      assert_equal "X-TEST-CURRENT-USER", harness.send(:test_header_key)

      harness.actor_type = "staff"

      assert_equal "X-TEST-CURRENT-STAFF", harness.send(:test_header_key)

      harness.actor_type = "viewer"

      assert_equal "X-TEST-CURRENT-VIEWER", harness.send(:test_header_key)

      harness.actor_type = "unknown"

      assert_equal "X-TEST-CURRENT-RESOURCE", harness.send(:test_header_key)
    end

    test "device cookie helper methods are defined" do
      assert Authentication::Base.private_method_defined?(:set_device_id_cookie!),
             "Authentication::Base should define set_device_id_cookie!"
      assert Authentication::Base.private_method_defined?(:clear_device_id_cookie!),
             "Authentication::Base should define clear_device_id_cookie!"
      assert Authentication::Base.private_method_defined?(:read_device_id_cookie),
             "Authentication::Base should define read_device_id_cookie"
    end

    test "ACCESS_TOKEN_TTL is defined" do
      assert_kind_of ActiveSupport::Duration, Authentication::Base::ACCESS_TOKEN_TTL
    end

    test "REFRESH_TOKEN_TTL is defined" do
      assert_kind_of ActiveSupport::Duration, Authentication::Base::REFRESH_TOKEN_TTL
    end

    test "Token class has JWT_ALGORITHM constant" do
      assert_equal "ES384", Authentication::Base::Token::JWT_ALGORITHM
    end

    test "Token.extract_subject returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_subject(nil)
    end

    test "VALID_ACTOR_TYPES constant is defined" do
      assert_equal %w(user staff), Authentication::Base::VALID_ACTOR_TYPES
    end

    test "Token.extract_act returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_act(nil)
    end

    test "Token.extract_type returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_type(nil)
    end

    test "Token.extract_session_id returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_session_id(nil)
    end

    test "Token.extract_jti returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_jti(nil)
    end

    test "JwtConfiguration.issuer returns string" do
      issuer = Authentication::Base::JwtConfiguration.issuer

      assert_kind_of String, issuer
    end

    test "JwtConfiguration.audiences returns array" do
      audiences = Authentication::Base::JwtConfiguration.audiences

      assert_kind_of Array, audiences
    end

    test "JwtConfiguration.leeway_seconds returns integer" do
      assert_kind_of Integer, Authentication::Base::JwtConfiguration.leeway_seconds
    end

    test "MissingPolicyError is a StandardError" do
      assert_operator Authentication::Base::MissingPolicyError, :<, StandardError
    end

    test "InvalidPolicyError is a StandardError" do
      assert_operator Authentication::Base::InvalidPolicyError, :<, StandardError
    end

    test "SkipNotAllowedError is a StandardError" do
      assert_operator Authentication::Base::SkipNotAllowedError, :<, StandardError
    end

    test "request guard helpers render or redirect when already logged in" do
      harness = HeaderKeyHarness.new
      harness.logged_in = true

      harness.ensure_not_logged_in

      assert_equal "この操作を行う権限がありません。", harness.rendered[:plain]
      assert_equal :unauthorized, harness.rendered[:status]

      harness.ensure_not_logged_in(message_key: "auth.denied")

      assert_equal "translated:auth.denied", harness.rendered[:plain]

      assert harness.reject_if_logged_in("auth.bad_request")
      assert_equal "translated:auth.bad_request", harness.rendered[:plain]
      assert_equal :bad_request, harness.rendered[:status]

      harness.json_request!
      harness.ensure_not_logged_in_for_registration(redirect_path: "/dashboard", message_key: "auth.denied")

      assert_equal :unauthorized, harness.rendered[:status]

      harness.html_request!
      harness.ensure_not_logged_in_for_registration(redirect_path: "/dashboard", message_key: "auth.denied")

      assert_equal ["/dashboard", { alert: "translated:auth.denied" }], harness.redirected
    end

    test "request guard helpers no-op when not logged in" do
      harness = HeaderKeyHarness.new

      assert_nil harness.ensure_not_logged_in
      assert_not harness.reject_if_logged_in("auth.bad_request")
      assert_nil harness.ensure_not_logged_in_for_registration
      assert_nil harness.rendered
      assert_nil harness.redirected
    end

    test "redirect parameter helpers preserve peek retrieve and build params" do
      harness = HeaderKeyHarness.new
      harness.params = { rd: "/target" }

      assert_equal "/target", harness.preserve_redirect_parameter
      assert_equal "/target", harness.session[Authentication::Base::DEFAULT_RD_SESSION_KEY]
      assert_equal "/target", harness.peek_redirect_parameter
      assert_equal({ notice: "ok", rd: "/target" }, harness.build_notice_params("ok"))
      assert_equal({ alert: "ng", rd: "/target" }, harness.build_alert_params("ng"))
      assert_equal "/target", harness.retrieve_redirect_parameter
      assert_nil harness.session[Authentication::Base::DEFAULT_RD_SESSION_KEY]
    end

    test "redirect_with_rd_handling uses rd jump when present and fallback redirect otherwise" do
      harness = HeaderKeyHarness.new
      harness.session[Authentication::Base::DEFAULT_RD_SESSION_KEY] = "/encoded"

      harness.redirect_with_rd_handling("/default", :notice, "done")

      assert_equal "done", harness.flash[:notice]
      assert_equal ["/encoded", "/default"], harness.jumped

      harness.redirect_with_rd_handling("/default", :alert, "warn")

      assert_equal ["/default", { alert: "warn" }], harness.redirected
    end

    test "set_device_id_cookie! and read_device_id_cookie" do
      harness = HeaderKeyHarness.new
      expires_at = 1.day.from_now
      HeaderKeyHarness.reset_encrypted_cookies!

      Core::CookieOptions.stub(:for, {}) do
        harness.send(:set_device_id_cookie!, "dev-123", expires_at: expires_at)

        # Cookie is now stored as plaintext (not encrypted) with options
        cookie_value = harness.cookies[Authentication::Base::DEVICE_COOKIE_KEY]

        assert_equal "dev-123", cookie_value.is_a?(Hash) ? cookie_value[:value] : cookie_value

        # Set cookie directly for reading test
        harness.cookies[Authentication::Base::DEVICE_COOKIE_KEY] = "dev-123"

        assert_equal "dev-123", harness.send(:read_device_id_cookie)
      end
    end

    test "clear_auth_cookies! deletes all auth-related cookies" do
      harness = HeaderKeyHarness.new
      HeaderKeyHarness.reset_encrypted_cookies!
      harness.cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "access"
      harness.cookies.encrypted[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh"

      Core::CookieOptions.stub(:for, {}) do
        harness.send(:clear_auth_cookies!)

        assert_nil harness.cookies[Authentication::Base::ACCESS_COOKIE_KEY]
        assert_nil harness.cookies[Authentication::Base::REFRESH_COOKIE_KEY]
      end
    end

    test "JwtConfiguration.issuer respects resource_type" do
      assert_equal "umaxica-auth:user", Authentication::Base::JwtConfiguration.issuer("user")
      assert_equal "umaxica-auth:staff", Authentication::Base::JwtConfiguration.issuer("staff")
      assert_equal "umaxica-auth", Authentication::Base::JwtConfiguration.issuer("invalid")
    end

    test "JwtConfiguration.audiences respects resource_type specific env" do
      with_env("AUTH_JWT_USER_AUDIENCES" => "u1,u2", "AUTH_JWT_AUDIENCES" => "default") do
        assert_equal %w(u1 u2), Authentication::Base::JwtConfiguration.audiences("user")
        assert_equal %w(default), Authentication::Base::JwtConfiguration.audiences("staff")
      end
    end

    test "JwtConfiguration.token_type returns correct format" do
      assert_equal "auth-access-token;user", Authentication::Base::JwtConfiguration.token_type("user")
      assert_equal "auth-access-token;staff", Authentication::Base::JwtConfiguration.token_type("staff")
      assert_raises(ArgumentError) { Authentication::Base::JwtConfiguration.token_type("invalid") }
    end

    private

    def with_env(vars)
      original = vars.keys.index_with { |k| ENV[k] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      original.each { |k, v| ENV[k] = v }
    end
  end
end
