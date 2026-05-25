# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

module Auth
  class BaseTest < ActiveSupport::TestCase
    fixtures_none!

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

      attr_accessor :actor_type, :checkpoint_participant, :dashboard_participant
      attr_writer :resource, :logged_in, :current_session_record, :allowed_policy

      def resource_type
        actor_type
      end

      def resource_class = Client

      def token_class = ClientToken

      def audit_class = ClientChronicle

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
        @request_stub = Struct.new(:format, :host, :request_id, :remote_ip, :headers).new(
          Struct.new(:json?).new(false),
          "app.localhost", "req-123", "127.0.0.1", {},
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
        return @resource if defined?(@resource)

        @logged_in ? Object.new : nil
      end

      def current_session
        @current_session_record
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
        @request_stub = Struct.new(:format, :headers).new(Struct.new(:json?).new(true), {})
      end

      def html_request!
        @request_stub = Struct.new(:format, :headers).new(Struct.new(:json?).new(false), {})
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

      def sign_in_sequence_surface
        :app
      end

      def sign_app_dashboard_path(ri: nil, rt: nil)
        path = "/dashboard"
        query = []
        query << "ri=#{ri}" if ri.present?
        query << "rt=#{rt}" if rt.present?
        query.any? ? "#{path}?#{query.join("&")}" : path
      end

      def sign_app_welcome_path(_id = "post_auth", ri: nil, rt: nil)
        path = "/welcome"
        query = []
        query << "ri=#{ri}" if ri.present?
        query << "rt=#{rt}" if rt.present?
        query.any? ? "#{path}?#{query.join("&")}" : path
      end

      def sign_app_configuration_path(ri: nil)
        ri.present? ? "/configuration?ri=#{ri}" : "/configuration"
      end

      def sign_app_in_checkpoint_path(ri: nil, rt: nil)
        path = "/sign/in/checkpoint"
        query = []
        query << "ri=#{ri}" if ri.present?
        query << "rt=#{rt}" if rt.present?
        query.any? ? "#{path}?#{query.join("&")}" : path
      end

      def allowed_to?(rule = nil, *)
        if defined?(@allowed_policy) && @allowed_policy.is_a?(Hash)
          return @allowed_policy.fetch(rule)
        end

        return true unless defined?(@allowed_policy)

        @allowed_policy
      end

      def sign_in_checkpoint_participant(cycle)
        checkpoint_participant || super
      end

      def sign_in_dashboard_participant(cycle)
        dashboard_participant || super
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

    ResourceStub = Struct.new(:id)
    BlockingParticipant =
      Struct.new(:cycle) do
        def advance_if_clear!
          SignIn::ParticipantResult.new(
            participant: :checkpoint,
            stack: [SignIn::ParticipantItem.new(key: :blocked_for_test, blocking: true, cleared: false)],
            next_status: "DASHBOARD_PENDING",
          )
        end
      end

    test "VALID_POLICIES constant is defined" do
      assert_equal %i(deny_all public_strict auth_required guest_only), Authentication::Base::VALID_POLICIES
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

      harness.actor_type = "client"

      assert_equal "X-TEST-CURRENT-USER", harness.send(:test_header_key)

      harness.actor_type = "operator"

      assert_equal "X-TEST-CURRENT-STAFF", harness.send(:test_header_key)

      harness.actor_type = "viewer"

      assert_equal "X-TEST-CURRENT-VIEWER", harness.send(:test_header_key)

      harness.actor_type = "unknown"

      assert_equal "X-TEST-CURRENT-RESOURCE", harness.send(:test_header_key)
    end

    test "device cookie helper methods are defined" do
      assert HeaderKeyHarness.private_method_defined?(:set_device_id_cookie!),
             "HeaderKeyHarness should define set_device_id_cookie!"
      assert HeaderKeyHarness.private_method_defined?(:clear_device_id_cookie!),
             "HeaderKeyHarness should define clear_device_id_cookie!"
      assert HeaderKeyHarness.private_method_defined?(:read_device_id_cookie),
             "HeaderKeyHarness should define read_device_id_cookie"
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
      assert_equal %w(client operator visitor), Authentication::Base::VALID_ACTOR_TYPES
    end

    test "Token.extract_act returns nil for nil payload" do
      assert_nil Authentication::Base::Token.extract_act(nil)
    end

    test "begin_sign_in_sequence stores only safe encoded return paths" do
      harness = HeaderKeyHarness.new
      harness.resource = ResourceStub.new(42)
      Actor.tld = :app
      Actor.install_context!(authn: Actor::Authentication.new(amr: ["email_otp"]))

      unsafe_result = harness.send(
        :begin_sign_in_sequence!,
        rt: "https://evil.example/phish",
        checkpoint_required: true,
      )

      assert_equal :success, unsafe_result.status
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("rt")
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("safe_return_path")

      safe_result = harness.send(:begin_sign_in_sequence!, rt: "/configuration", checkpoint_required: true)

      assert_equal :success, safe_result.status
      stored_rt = harness.session.fetch(:app_sign_in_sequence).fetch("rt")
      stored_safe_return_path = harness.session.fetch(:app_sign_in_sequence).fetch("safe_return_path")

      assert_equal "/configuration", harness.return_path_from_signed_rt(stored_rt)
      assert_equal "/configuration", harness.return_path_from_signed_rt(stored_safe_return_path)

      welcome_rt = "/welcome?ri=jp"
      welcome_result = harness.send(:begin_sign_in_sequence!, rt: welcome_rt, checkpoint_required: true)

      assert_equal :success, welcome_result.status
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("rt")
      assert_nil harness.session.fetch(:app_sign_in_sequence).fetch("safe_return_path")
    ensure
      Actor.reset
    end

    test "checkpoint continuation uses db-backed sign-in cycle when locator is present" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_checkpoint_sequence_without_content!)

      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      redirected = URI.parse(harness.redirected.first)

      assert_equal "/welcome", redirected.path
      assert_equal "/after",
                   harness.return_path_from_signed_rt(Rack::Utils.parse_query(redirected.query).fetch("rt"))
      assert_equal 5, harness.session[:app_sign_in_welcome]["remaining"]
    end

    test "checkpoint continuation can carry dashboard as rt" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      cycle.update!(return_to: "/dashboard?ri=jp")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_checkpoint_sequence_without_content!)

      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      redirected = URI.parse(harness.redirected.first)

      assert_equal "/welcome", redirected.path
      assert_equal "/dashboard?ri=jp",
                   harness.return_path_from_signed_rt(Rack::Utils.parse_query(redirected.query).fetch("rt"))
    end

    test "checkpoint continuation keeps blocking db-backed cycle at checkpoint" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      harness.checkpoint_participant = BlockingParticipant.new(cycle)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_checkpoint_sequence_without_content!)

      assert_nil harness.redirected
      assert_nil harness.rendered
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "dashboard continuation consumes db-backed return path before rendering welcome page" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, rt: "/after", sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal "/after", harness.instance_variable_get(:@welcome_next_path)
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
      assert_nil harness.session[:app_sign_in_welcome]
      assert_nil harness.session[:app_sign_in_cycle_locator]
    end

    test "dashboard continuation falls back when persisted return path points to dashboard" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      cycle.update!(return_to: "/dashboard?ri=jp")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, rt: cycle.return_to, sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal "/dashboard?ri=jp", harness.instance_variable_get(:@welcome_next_path)
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "dashboard continuation falls back when resolved return path is welcome" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      cycle.update!(return_to: "/welcome?ri=jp")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, rt: cycle.return_to, sequence_id: cycle.public_id)

      harness.send(:continue_dashboard_sequence_without_content!)

      assert_nil harness.redirected
      assert_equal "/dashboard", harness.instance_variable_get(:@welcome_next_path)
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "dashboard continuation redirects checkpoint-pending cycle back to checkpoint" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "CHECKPOINT_PENDING", step: "checkpoint")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      harness.send(:continue_dashboard_sequence_without_content!)

      redirected = URI.parse(harness.redirected.first)

      assert_equal "/sign/in/checkpoint", redirected.path
      assert_equal "/after",
                   harness.return_path_from_signed_rt(Rack::Utils.parse_query(redirected.query).fetch("rt"))
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "dashboard continuation requires dashboard policy before advancing" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      harness = db_sequence_harness(user, token)
      harness.allowed_policy = { show_dashboard?: false }
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")
      harness.send(:issue_welcome_gate_and_path, rt: cycle.return_to, sequence_id: cycle.public_id)

      assert_not harness.send(:continue_dashboard_sequence_without_content!)

      assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :bad_request }, harness.rendered)
      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      assert_equal "/after", cycle.return_to
    end

    test "db-backed sequence rejects wrong participant without advancing" do
      user = create_db_sequence_client
      token = ClientToken.create!(user: user)
      cycle = db_sign_in_cycle(user, token, status_name: "DASHBOARD_PENDING", step: "dashboard")
      harness = db_sequence_harness(user, token)
      SignIn::CycleLocator.new(harness.session, surface: :app, actor: user, token: token).issue!(cycle, nonce: "nonce")

      assert_not harness.send(:continue_checkpoint_sequence_without_content!)

      assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :bad_request }, harness.rendered)
      assert_predicate cycle.reload, :sign_in_dashboard_pending?
    end

    test "checkpoint sequence participant rejects stale bulletin without sequence state" do
      harness = HeaderKeyHarness.new
      harness.allowed_policy = { show_checkpoint?: false }
      harness.session[Authentication::Base::BULLETIN_SESSION_KEY] = {
        "issued_at" => Time.current.to_i,
        "kind" => "checkpoint",
        "state" => "new",
        "bulletin_id" => 123,
      }

      assert_not harness.send(
        :require_sign_in_sequence_participant!,
        participant: :checkpoint,
        policy_rule: :show_checkpoint?,
      )

      assert_equal({ plain: I18n.t("errors.messages.not_authorized"), status: :bad_request }, harness.rendered)
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
      harness.params = { rt: "/target" }

      result = harness.preserve_redirect_parameter

      assert_equal "/target", harness.return_path_from_signed_rt(result)
      assert_equal result, harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY]
      assert_equal "/target", harness.return_path_from_signed_rt(harness.peek_redirect_parameter)
      assert_equal "/target", harness.return_path_from_signed_rt(harness.build_notice_params("ok")[:rt])
      assert_equal "/target", harness.return_path_from_signed_rt(harness.build_alert_params("ng")[:rt])
      assert_equal "/target", harness.return_path_from_signed_rt(harness.retrieve_redirect_parameter)
      assert_nil harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY]
    end

    test "redirect_with_rt_handling uses rt jump when present and fallback redirect otherwise" do
      harness = HeaderKeyHarness.new
      rt = harness.safe_encoded_rt("/dashboard")
      harness.session[Authentication::Base::DEFAULT_RT_SESSION_KEY] = rt

      harness.redirect_with_rt_handling("/default", :notice, "done")

      assert_equal "done", harness.flash[:notice]
      assert_equal [harness.return_path_from_signed_rt(rt), { allow_other_host: false }],
                   harness.redirected

      harness.redirect_with_rt_handling("/default", :alert, "warn")

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
      assert_equal "umaxica-auth:client", Authentication::Base::JwtConfiguration.issuer("client")
      assert_equal "umaxica-auth:operator", Authentication::Base::JwtConfiguration.issuer("operator")
      assert_equal "umaxica-auth", Authentication::Base::JwtConfiguration.issuer("invalid")
    end

    test "JwtConfiguration.audiences respects resource_type specific env" do
      with_env("AUTH_JWT_CLIENT_AUDIENCES" => "u1,u2", "AUTH_JWT_AUDIENCES" => "default") do
        assert_equal %w(u1 u2), Authentication::Base::JwtConfiguration.audiences("client")
        assert_equal %w(default), Authentication::Base::JwtConfiguration.audiences("operator")
      end
    end

    test "JwtConfiguration.token_type returns correct format" do
      assert_equal "auth-access-token;client", Authentication::Base::JwtConfiguration.token_type("client")
      assert_equal "auth-access-token;operator", Authentication::Base::JwtConfiguration.token_type("operator")
      assert_raises(ArgumentError) { Authentication::Base::JwtConfiguration.token_type("invalid") }
    end

    private

    def create_db_sequence_client
      ClientStatus.ensure_defaults!
      ClientVisibility.ensure_defaults!
      ClientMultiFactor.ensure_defaults!
      ClientMultiFactorStatus.ensure_defaults!
      ClientTokenBindingMethod.ensure_defaults!
      ClientTokenDbscStatus.ensure_defaults!
      ClientTokenKind.ensure_defaults!
      ClientTokenStatus.ensure_defaults!

      Client.create!(
        public_id: "u_#{SecureRandom.hex(8)}",
        status_id: ClientStatus::ACTIVE,
        visibility_id: ClientVisibility::USER,
        multi_factor_id: ClientMultiFactor::NOTHING,
        multi_factor_status_id: ClientMultiFactorStatus::UNCONFIGURED,
      )
    end

    def db_sequence_harness(user, token)
      HeaderKeyHarness.new.tap do |harness|
        harness.actor_type = "client"
        harness.resource = user
        harness.current_session_record = token
      end
    end

    def db_sign_in_cycle(user, token, status_name:, step:)
      ClientSignInCycle.create!(
        principal_id: user.id,
        token: token,
        status_id: ClientSignInCycle.status_id_for(status_name),
        step: step,
        return_to: "/after",
        nonce_digest: ClientSignInCycle.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      )
    end

    def with_env(vars)
      original = vars.keys.index_with { |k| ENV[k] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      original.each { |k, v| ENV[k] = v }
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
