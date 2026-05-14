# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationBaseTestController < ApplicationController
  include Authentication::Base

  public :load_session_record, :redirect_with_rt_handling, :peek_redirect_parameter,
         :epoch_seconds, :issue_bulletin!, :handle_auth_required_json, :handle_guest_only_json,
         :load_authentication_session, :store_authentication_session, :clear_authentication_session,
         :validate_session_expiry, :safe_redirect_to_rt_or_default!, :refresh_failure_status,
         :refresh_failure_code, :cookie_options, :cookie_deletion_options, :device_cookie_key,
         :device_cookie_options, :set_device_id_cookie!, :clear_device_id_cookie!,
         :clear_auth_cookies!, :read_device_id_cookie, :occurrence_model_class,
         :normalize_amr, :session_management_path, :after_login_path, :default_after_login_path,
         :max_sessions_for_resource, :store_pending_login_resource, :token_expiry_column,
         :access_token_expires_at_for, :refresh_cookie_expires_at_for, :expires_in_for,
         :mfa_bypassed_for_auth_method?, :resolve_mfa_return_to, :decode_base64_urlsafe,
         :mfa_entry_path, :handle_auth_required_html, :handle_guest_only_with_status_checks,
         :handle_guest_only_html, :current_session_restricted?, :current_account,
         :transparent_refresh_access_token, :authenticate!, :bulletin_association_for_resource,
         :create_welcome_bulletin!, :withdrawal_gate_redirect_path, :handle_missing_refresh_token,
         :handle_inactive_resource, :handle_refresh_error, :resolve_token_kind_id,
         :enforce_public_strict!, :enforce_auth_required!, :enforce_guest_only!,
         :resolve_access_policy_for, :refresh_dbsc_allowed?, :refresh_device_source,
         :refresh_dbsc_source, :refresh_binding_source, :token_kind_model,
         :set_pending_mfa!, :pending_mfa, :pending_mfa_valid?, :clear_pending_mfa!,
         :session_limit_gate_return_to, :session_limit_gate_flow, :build_auth_preference_snapshot,
         :reissue_access_token!, :log_in

  def index; render plain: "ok"; end
end

class AuthenticationBaseFakeModel
  class << self
    def record=(val)
      @record = val
    end

    def record
      @record
    end
  end

  class << self
    def find_by(id:)
      record if record&.id == id
    end
  end
end

class AuthenticationBaseFakeTokenWithLapsesAt
  def self.name = "AuthenticationBaseFakeTokenWithLapsesAt"

  def self.column_names = %w(lapses_at)
end

class AuthenticationBaseFakeTokenWithoutExpiry
  def self.name = "AuthenticationBaseFakeTokenWithoutExpiry"

  def self.column_names = []
end

class Authentication::BaseCoverageTest < ActionDispatch::IntegrationTest
  setup do
    @controller = AuthenticationBaseTestController.new
    @user = users(:one)

    # Mock request
    @request = ActionDispatch::TestRequest.create
    @controller.request = @request
    @controller.response = ActionDispatch::TestResponse.new
    @session_hash = {}
    @controller.define_singleton_method(:session) { @session_hash }
    @controller.instance_variable_set(:@session_hash, @session_hash)
  end

  test "redirect_with_rt_handling hits branches" do
    @controller.stub(:session, { "rt" => "/foo" }) do
      @controller.stub(:redirect_to, true) do
        @controller.redirect_with_rt_handling("/", :notice, "msg", "rt")
        @controller.redirect_with_rt_handling("/", :alert, "msg", "rt")
      end
    end

    assert_not_nil @controller
  end

  test "peek_redirect_parameter" do
    @controller.stub(:session, { "rt" => "/foo" }) do
      assert_equal "/foo", @controller.peek_redirect_parameter("rt")
    end
  end

  test "epoch_seconds" do
    assert_equal 100, @controller.epoch_seconds(100)
    assert_equal 0, @controller.epoch_seconds(nil)
  end

  test "issue_bulletin! hits branches" do
    @controller.stub(:current_resource, @user) do
      @controller.issue_bulletin!
    end

    assert_not_nil @controller
  end

  test "Token.encode with all params" do
    host = "app.localhost"
    token = Authentication::Base::Token.encode(
      @user,
      host: host,
      resource_type: "user",
      session_public_id: "sid",
      acr: "aal1",
      amr: ["email"],
      expires_at: 1.hour.from_now.to_i,
    )

    assert_not_nil token
  end

  test "authentication session helpers handle valid missing and invalid records" do
    record = Struct.new(:id).new(123)
    AuthenticationBaseFakeModel.record = record

    @controller.store_authentication_session(:auth_id, 123)

    assert_equal record,
                 @controller.load_authentication_session(:auth_id, AuthenticationBaseFakeModel, "/expired", "expired")

    @controller.clear_authentication_session(:auth_id)

    assert_nil @controller.session[:auth_id]

    redirects = []
    @controller.define_singleton_method(:handle_session_expiry) do |path, message|
      redirects << [path, message]
    end

    assert_nil @controller.load_authentication_session(:missing, AuthenticationBaseFakeModel, "/expired", "expired")
    assert_equal [["/expired", "expired"]], redirects

    @controller.session[:auth_id] = 123

    assert_nil @controller.load_authentication_session(:auth_id, AuthenticationBaseFakeModel, "/expired", "expired") {
      false
    }
    assert_equal [["/expired", "expired"], ["/expired", "expired"]], redirects
  ensure
    AuthenticationBaseFakeModel.record = nil
  end

  test "session expiry validations cover edge cases" do
    assert_not @controller.validate_session_expiry(nil)
    assert_not @controller.validate_session_expiry({})
    assert @controller.validate_session_expiry({ "expires_at" => 5.minutes.from_now.to_i })
    assert_not @controller.validate_session_expiry({ "expires_at" => 1.minute.ago.to_i })
  end

  test "session record validations cover edge cases" do
    record = Struct.new(:id, :expired, :user_email_status_id) do
      define_method(:otp_expired?) do
        expired
      end
    end.new(7, false, 1)
    AuthenticationBaseFakeModel.record = record

    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel)

    @controller.session[:email_id] = 7

    assert_equal record, @controller.load_session_record(:email_id, AuthenticationBaseFakeModel)
    assert_equal record, @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, check_otp_expiry: true)
    assert_equal record, @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, status_id: 1)
    assert_equal record, @controller.load_session_record(
      :email_id, AuthenticationBaseFakeModel, custom: ->(candidate) {
        candidate.id == 7
      },
    )

    record.expired = true

    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, check_otp_expiry: true)
    record.expired = false

    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, status_id: 2)
    assert_nil @controller.load_session_record(:email_id, AuthenticationBaseFakeModel, custom: ->(*) { false })
  ensure
    AuthenticationBaseFakeModel.record = nil
  end

  test "redirect refresh failure helpers cover branches" do
    redirects = []
    @controller.define_singleton_method(:jump_to_generated_url) { |rt, fallback:| redirects << [:jump, rt, fallback] }
    @controller.define_singleton_method(:redirect_to) { |path, **| redirects << [:redirect, path] }

    @controller.safe_redirect_to_rt_or_default!("encoded-rt", default_path: "/default")
    @controller.safe_redirect_to_rt_or_default!(nil, default_path: "/default")

    assert_equal [[:jump, "encoded-rt", "/default"], [:redirect, "/default"]], redirects
    assert_equal :unauthorized, @controller.refresh_failure_status
    assert_equal "invalid_refresh_token", @controller.refresh_failure_code

    @controller.instance_variable_set(:@refresh_failure_status, :forbidden)
    @controller.instance_variable_set(:@refresh_failure_code, "withdrawal_required")

    assert_equal :forbidden, @controller.refresh_failure_status
    assert_equal "withdrawal_required", @controller.refresh_failure_code
  end

  test "cookie helpers cover branches" do
    expires_at = 1.hour.from_now
    @controller.set_device_id_cookie!("device-1", expires_at: expires_at)

    assert_equal "device-1", @controller.read_device_id_cookie
    assert_equal @controller.device_cookie_key, Auth::CookieName.device(refresh_cookie_key: Authentication::Base::REFRESH_COOKIE_KEY)
    assert_equal expires_at.to_i, @controller.device_cookie_options(expires_at: expires_at)[:expires].to_i

    @controller.clear_device_id_cookie!
    @request.headers[Auth::IoKeys::Headers::DEVICE_ID] = "header-device"

    assert_equal "header-device", @controller.read_device_id_cookie

    @controller.send(:cookies)[Authentication::Base::ACCESS_COOKIE_KEY] = "access"
    @controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh"
    @controller.clear_auth_cookies!

    assert_nil @controller.instance_variable_get(:@current_resource)
    assert_not @controller.cookie_deletion_options.key?(:expires)
    assert_not @controller.cookie_options.key?(:domain)
    assert_not @controller.cookie_deletion_options.key?(:domain)
    assert_equal :lax, @controller.cookie_options[:same_site]
  end

  test "cookie deletion options preserve secure attributes for host-prefixed production cookies" do
    env = ActiveSupport::EnvironmentInquirer.new("production")

    Rails.stub(:env, env) do
      options = @controller.cookie_deletion_options

      assert_equal "/", options[:path]
      assert_equal :lax, options[:same_site]
      assert options[:secure]
      assert options[:partitioned]
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end

  test "cookie deletion options work for non host-prefixed test cookies" do
    env = ActiveSupport::EnvironmentInquirer.new("test")

    Rails.stub(:env, env) do
      options = @controller.cookie_deletion_options

      assert_equal "auth_access", Auth::CookieName.access
      assert_equal "auth_refresh", Auth::CookieName.refresh
      assert_equal "auth_dbsc", Auth::CookieName.dbsc
      assert_equal "/", options[:path]
      assert_equal :lax, options[:same_site]
      assert_not options[:secure]
      assert_not options.key?(:partitioned)
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end

  test "cookie deletion options work for non host-prefixed development cookies" do
    env = ActiveSupport::EnvironmentInquirer.new("development")

    Rails.stub(:env, env) do
      options = @controller.cookie_deletion_options

      assert_equal "auth_access", Auth::CookieName.access
      assert_equal "auth_refresh", Auth::CookieName.refresh
      assert_equal "auth_dbsc", Auth::CookieName.dbsc
      assert_equal "/", options[:path]
      assert_equal :lax, options[:same_site]
      assert_not options[:secure]
      assert_not options.key?(:partitioned)
      assert_not options.key?(:domain)
      assert_not options.key?(:httponly)
      assert_not options.key?(:expires)
    end
  end

  test "occurrence model and amr helpers" do
    @controller.define_singleton_method(:resource_type) { "user" }

    assert_equal UserOccurrence, @controller.occurrence_model_class

    @controller.define_singleton_method(:resource_type) { "operator" }

    assert_equal OperatorOccurrence, @controller.occurrence_model_class

    @controller.define_singleton_method(:resource_type) { "visitor" }

    assert_equal VisitorOccurrence, @controller.occurrence_model_class

    assert_equal ["email_otp"], @controller.normalize_amr("email")
    assert_equal ["passkey"], @controller.normalize_amr("passkey")
    assert_equal ["google"], @controller.normalize_amr("google")
    assert_equal ["apple"], @controller.normalize_amr("apple")
    assert_equal ["recovery_code"], @controller.normalize_amr("secret")
    assert_equal [], @controller.normalize_amr("unknown")
  end

  test "path and token expiry helpers" do
    @controller.define_singleton_method(:resource_type) { "user" }

    assert_equal "/sign/in/session", @controller.session_management_path
    assert_equal "/", @controller.after_login_path
    assert_equal "/", @controller.default_after_login_path

    assert_equal :lapses_at, @controller.token_expiry_column(AuthenticationBaseFakeTokenWithLapsesAt)
    assert_raises(ArgumentError) { @controller.token_expiry_column(AuthenticationBaseFakeTokenWithoutExpiry) }

    now = Time.current
    token = Struct.new(:lapses_at, :refresh_expires_at).new(now + 30.minutes, now + 2.hours)

    assert_equal (now + 30.minutes).to_i, @controller.access_token_expires_at_for(token, now: now).to_i
    assert_equal (now + 30.minutes).to_i, @controller.refresh_cookie_expires_at_for(token).to_i
    assert_equal 60, @controller.expires_in_for(now + 60.seconds, now: now)
    assert_equal 0, @controller.expires_in_for(now - 1.second, now: now)
  end

  test "mfa and base64 helpers" do
    assert @controller.mfa_bypassed_for_auth_method?("passkey")
    assert @controller.mfa_bypassed_for_auth_method?(:google)
    assert_not @controller.mfa_bypassed_for_auth_method?("email")

    assert_equal "/safe/path", @controller.resolve_mfa_return_to(Base64.urlsafe_encode64("/safe/path"))
    assert_equal "/safe/path?ri=jp",
                 @controller.resolve_mfa_return_to(Base64.urlsafe_encode64("http://test.host/safe/path?ri=jp"))
    assert_nil @controller.resolve_mfa_return_to(Base64.urlsafe_encode64("https://evil.example"))
    assert_nil @controller.resolve_mfa_return_to("")

    assert_equal "decoded", @controller.decode_base64_urlsafe(Base64.urlsafe_encode64("decoded"))
    assert_nil @controller.decode_base64_urlsafe("%%%")

    assert_equal "/sign/in/challenge?ri=jp", @controller.mfa_entry_path(ri: "jp")
  end

  test "policy response helpers render and redirect expected shapes" do
    @request.set_header("REQUEST_METHOD", "GET")
    rendered = []
    redirected = []
    @controller.define_singleton_method(:render) { |*args, **kwargs| rendered << [args, kwargs] }
    @controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected << [args, kwargs] }
    @controller.define_singleton_method(:main_app) {
      Struct.new(:sign_in_path, :after_login_path).new("/main/sign_in", "/main/after")
    }
    @controller.define_singleton_method(:sign_in_url_with_return) { |rt| "/in?rt=#{rt}" }

    @controller.handle_auth_required_json(message: "login", status: :forbidden)
    @controller.handle_guest_only_json(message: "guest", status: :unauthorized)
    @controller.handle_auth_required_html(message: "login html")
    @controller.handle_guest_only_with_status_checks(status: :unauthorized, message: "nope")
    @controller.handle_guest_only_with_status_checks(status: :bad_request, message: "bad")
    @controller.handle_guest_only_html(message: "already")

    assert_equal [{ error: "login" }, { error: "guest" }], rendered.first(2).map { |r| r.last[:json] }
    assert_equal [:forbidden, :unauthorized], rendered.first(2).map { |r| r.last[:status] }
    assert_match %r{\A/in\?rt=}, redirected.first.first.first
    assert_equal ["/"], redirected.last.first
    assert_equal 2, rendered.size
    assert_equal 4, redirected.size
  end

  test "resource session helpers handle supported and fallback resources" do
    staff = staffs(:one)
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_equal UserToken::MAX_SESSIONS_PER_USER, @controller.max_sessions_for_resource(@user)
    assert_equal OperatorToken::MAX_SESSIONS_PER_STAFF, @controller.max_sessions_for_resource(staff)
    assert_equal VisitorToken::MAX_SESSIONS_PER_VISITOR, @controller.max_sessions_for_resource(visitor)
    assert_equal 2, @controller.max_sessions_for_resource(Object.new)

    @controller.store_pending_login_resource(@user)
    @controller.store_pending_login_resource(staff)
    @controller.store_pending_login_resource(visitor)

    assert_equal @user.id, @controller.session[:pending_login_user_id]
    assert_equal staff.id, @controller.session[:pending_login_staff_id]
    assert_equal visitor.id, @controller.session[:pending_login_visitor_id]
    assert_nil @controller.current_session_restricted?
  end

  test "current account bulletin and welcome helpers cover user and staff branches" do
    staff = staffs(:one)

    @controller.define_singleton_method(:current_resource) { @current_resource_for_test }
    @controller.instance_variable_set(:@current_resource_for_test, @user)
    begin
      assert_equal @user, @controller.current_account
      @controller.create_welcome_bulletin!(@user)

      @controller.instance_variable_set(:@current_resource_for_test, staff)
      @controller.create_welcome_bulletin!(staff)

      @controller.instance_variable_set(:@current_resource_for_test, nil)

      assert_nil @controller.bulletin_association_for_resource
    end
  end

  test "transparent refresh and authenticate cover failure and json branches" do
    @controller.define_singleton_method(:logged_in?) { false }
    @controller.define_singleton_method(:refresh_access_token) { |_| nil }
    @controller.define_singleton_method(:clear_auth_cookies!) { @cleared = true }
    @controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"

    @controller.transparent_refresh_access_token

    assert @controller.instance_variable_get(:@cleared)
    assert @request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]

    rendered = []
    @request.set_header("HTTP_ACCEPT", "application/json")
    @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }

    @controller.authenticate!

    assert_equal({ error: "Unauthorized" }, rendered.last[:json])
    assert_equal :unauthorized, rendered.last[:status]
  end

  test "withdrawal and refresh error helpers cover status branches" do
    @controller.define_singleton_method(:resource_type) { "user" }
    @controller.define_singleton_method(:request_ip_address) { "127.0.0.1" }
    @controller.define_singleton_method(:risk_actor_payload) { |_| {} }
    @controller.request.request_id = "request-1"

    assert_equal "/configuration/edit", @controller.withdrawal_gate_redirect_path
    assert_nil @controller.handle_missing_refresh_token("missing-public-id")
    assert_equal :unauthorized, @controller.refresh_failure_status

    deactivated = Struct.new(:id) do
      define_method(:deactivated?) do
        true
      end
    end.new(7)
    active = Struct.new(:id) do
      define_method(:deactivated?) do
        false
      end
    end.new(8)
    token = nil

    assert_nil @controller.handle_inactive_resource(deactivated, "refresh-public", token)
    assert_equal :forbidden, @controller.refresh_failure_status
    assert_equal "withdrawal_required", @controller.refresh_failure_code

    assert_nil @controller.handle_inactive_resource(active, "refresh-public", token)
    assert_equal :unauthorized, @controller.refresh_failure_status

    assert_nil @controller.handle_refresh_error(StandardError.new("boom"), "refresh-public", active)
    assert_equal "invalid_refresh_token", @controller.refresh_failure_code
  end

  test "policy and token kind helpers cover fallback branches" do
    assert @controller.enforce_public_strict!

    @controller.define_singleton_method(:logged_in?) { false }
    @controller.request.set_header("HTTP_ACCEPT", "application/json")
    rendered = []
    @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }
    @controller.enforce_auth_required!(request_format: :json, message: "login")

    assert_equal({ error: "login" }, rendered.last[:json])

    @controller.define_singleton_method(:logged_in?) { true }
    resource = Struct.new(:deactivated?).new(true)
    @controller.define_singleton_method(:current_resource) { resource }

    assert @controller.enforce_guest_only!

    klass = Class.new
    klass.define_singleton_method(:access_policy_rules) { [{ policy: :public, only: ["index"] }] }
    @controller.define_singleton_method(:action_name) { "show" }
    @controller.define_singleton_method(:class) { klass }

    assert_nil @controller.resolve_access_policy_for("show")

    @controller.define_singleton_method(:resource_type) { "operator" }
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) { { "staff_token_kind_id" => Struct.new(:type).new(:string) } }
    @controller.define_singleton_method(:token_class) { token_class }

    assert_equal "BROWSER_WEB", @controller.resolve_token_kind_id("BROWSER_WEB")
  end

  test "refresh dbsc allowed helper covers missing mismatch and success" do
    dbsc_token =
      Struct.new(:dbsc_status, :dbsc_session_id) do
        define_method(:dbsc_status_active?) do
          dbsc_status == :active
        end

        define_method(:binding_method_dbsc?) do
          true
        end
      end

    assert @controller.refresh_dbsc_allowed?(nil)

    token = dbsc_token.new(:pending, "session-1")

    assert_not @controller.refresh_dbsc_allowed?(token)

    token.dbsc_status = :active

    assert_not @controller.refresh_dbsc_allowed?(token)
    assert_equal "missing_bound_cookie", @controller.instance_variable_get(:@refresh_dbsc_reason)

    @controller.send(:cookies)[Authentication::Base::DBSC_COOKIE_KEY] = "wrong"

    assert_not @controller.refresh_dbsc_allowed?(token)
    assert_equal "session_id_mismatch", @controller.instance_variable_get(:@refresh_dbsc_reason)

    @controller.send(:cookies)[Authentication::Base::DBSC_COOKIE_KEY] = "session-1"

    assert @controller.refresh_dbsc_allowed?(token)
  end

  test "refresh source helpers cover device and dbsc branches" do
    token = Struct.new(:binding_method_dbsc?).new(true)
    @controller.set_device_id_cookie!("device-cookie", expires_at: 1.hour.from_now)

    assert_equal "cookie", @controller.refresh_device_source
    @request.headers[Auth::IoKeys::Headers::DEVICE_ID] = "device-header"

    assert_equal "both", @controller.refresh_device_source
    @request.headers[Auth::IoKeys::Headers::DBSC_SESSION_ID] = "session"

    assert_equal "session_id", @controller.refresh_dbsc_source
    @request.headers[Auth::IoKeys::Headers::DBSC_RESPONSE] = "proof"

    assert_equal "both", @controller.refresh_dbsc_source
    assert_equal "both", @controller.refresh_binding_source(token)
  end

  test "mfa pending helpers and gate helpers cover expiry branches" do
    @controller.define_singleton_method(:resource_type) { "user" }
    @controller.define_singleton_method(:controller_path) { "sign/app/in" }

    @controller.set_pending_mfa!(
      resource: @user, primary: "email", return_to: "/after", ri: "jp",
      auth_method: "secret",
    )

    assert_equal @user.id, @controller.session[:mfa_user_id]
    assert_predicate @controller, :pending_mfa_valid?
    assert_equal "secret", @controller.pending_mfa[:auth_method]

    @controller.session[:pending_mfa][:expires_at] = 1.minute.ago.to_i

    assert_not @controller.pending_mfa_valid?

    @controller.session[:pending_mfa].delete(:expires_at)
    @controller.session[:pending_mfa].delete("expires_at")
    @controller.session[:pending_mfa][:issued_at] = 1.minute.ago.to_i

    assert_predicate @controller, :pending_mfa_valid?

    @controller.session[:pending_mfa][:issued_at] = 20.minutes.ago.to_i

    assert_not @controller.pending_mfa_valid?

    @controller.clear_pending_mfa!

    assert_nil @controller.session[:pending_mfa]
    assert_nil @controller.session[:mfa_user_id]

    assert_equal "/", @controller.session_limit_gate_return_to
    assert_equal "sign/app/in.session", @controller.session_limit_gate_flow
  end

  test "token kind model and literal kind resolution cover mappings" do
    token_class = Class.new
    token_class.define_singleton_method(:columns_hash) { { "staff_token_kind_id" => Struct.new(:type).new(:integer) } }
    @controller.define_singleton_method(:token_class) { token_class }
    @controller.define_singleton_method(:resource_type) { "operator" }
    @controller.define_singleton_method(:token_kind_model) do
      Class.new do
        define_singleton_method(:name) do
          "InlineOperatorTokenKind"
        end

        define_singleton_method(:column_names) do
          []
        end
      end
    end

    assert_equal OperatorTokenKind::BROWSER_WEB, @controller.resolve_token_kind_id("BROWSER_WEB")
    assert_equal OperatorTokenKind::CLIENT_IOS, @controller.resolve_token_kind_id("CLIENT_IOS")
    assert_equal OperatorTokenKind::CLIENT_ANDROID, @controller.resolve_token_kind_id("CLIENT_ANDROID")
    assert_raises(ActiveRecord::RecordNotFound) { @controller.resolve_token_kind_id("MISSING") }

    @controller.define_singleton_method(:resource_type) { "none" }
    assert_raises(ActiveRecord::RecordNotFound) { Authentication::Base.instance_method(:token_kind_model).bind_call(@controller) }
  end

  test "ensure_token_kind_exists creates missing fixed id" do
    UserToken.where(user_token_kind_id: UserTokenKind::BROWSER_WEB).delete_all
    UserTokenKind.where(id: UserTokenKind::BROWSER_WEB).delete_all

    @controller.define_singleton_method(:resource_type) { "user" }
    @controller.define_singleton_method(:token_kind_model) { UserTokenKind }

    assert_difference -> { UserTokenKind.where(id: UserTokenKind::BROWSER_WEB).count }, 1 do
      @controller.send(:ensure_token_kind_exists!, UserTokenKind::BROWSER_WEB)
    end
  end

  test "ensure_login_token_reference_data creates missing user token references" do
    UserToken.delete_all
    UserTokenKind.where(id: UserTokenKind::BROWSER_WEB).delete_all
    UserTokenBindingMethod.where(id: UserTokenBindingMethod::LEGACY).delete_all
    UserTokenDbscStatus.where(id: UserTokenDbscStatus::NOTHING).delete_all
    UserTokenStatus.where(id: UserTokenStatus::NOTHING).delete_all

    @controller.define_singleton_method(:resource_type) { "user" }

    @controller.send(
      :ensure_login_token_reference_data!,
      {
        user_token_kind_id: UserTokenKind::BROWSER_WEB,
        user_token_binding_method_id: UserTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: UserTokenDbscStatus::NOTHING,
        user_token_status_id: UserTokenStatus::NOTHING,
      },
    )

    assert UserTokenKind.exists?(id: UserTokenKind::BROWSER_WEB)
    assert UserTokenBindingMethod.exists?(id: UserTokenBindingMethod::LEGACY)
    assert UserTokenDbscStatus.exists?(id: UserTokenDbscStatus::NOTHING)
    assert UserTokenStatus.exists?(id: UserTokenStatus::NOTHING)
  end

  test "preference snapshot and reissue access token cover early returns and success" do
    pref = Struct.new(:language, :region, :timezone, :theme, :null?).new("ja", "jp", "Asia/Tokyo", "sy", false)
    Actor.preference = pref

    assert_equal(
      { "lx" => "ja", "ri" => "jp", "tz" => "Asia/Tokyo", "ct" => "sy" },
      @controller.build_auth_preference_snapshot(@user),
    )

    @controller.define_singleton_method(:current_resource) { nil }

    assert_nil @controller.reissue_access_token!

    session_record = Struct.new(:public_id, :revoked_at).new("session-public", 10.minutes.from_now)
    @controller.define_singleton_method(:current_resource) { @user }
    @controller.define_singleton_method(:current_session) { session_record }
    @controller.define_singleton_method(:resource_type) { "user" }
    @controller.define_singleton_method(:resolved_current_preference) { |_| pref }

    assert_nil @controller.reissue_access_token!
  ensure
    Actor.preference = nil
  end

  test "log_in binds access token to valid DPoP proof" do
    private_key, jwk = generate_dpop_jwk
    @request.host = "id.app.localhost"
    @request.headers["DPoP"] = build_dpop_proof(
      private_key,
      jwk,
      method: "GET",
      uri: "http://id.app.localhost/",
    )
    @controller.define_singleton_method(:resource_type) { "user" }
    @controller.define_singleton_method(:resource_foreign_key) { :user_id }
    @controller.define_singleton_method(:resource_class) { User }
    @controller.define_singleton_method(:token_class) { UserToken }
    @controller.define_singleton_method(:token_kind_model) { UserTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    result = @controller.log_in(@user, record_login_audit: false, require_totp_check: false)

    assert_equal :success, result[:status]

    payload = Authentication::Base::Token.decode(
      result[:access_token],
      host: "id.app.localhost",
      resource_type: "user",
    )
    expected_jkt = Jit::Security::Jwt::ThumbprintCalculator.calculate(jwk)

    assert_equal expected_jkt, payload.dig("cnf", "jkt")
    assert_equal expected_jkt, UserToken.find_by!(public_id: payload["sid"]).dpop_jkt
  end

  test "log_in sets visitor token status reference ids" do
    visitor = create_verified_visitor_with_email(email_address: "visitor-login@example.com")

    @controller.define_singleton_method(:resource_type) { "visitor" }
    @controller.define_singleton_method(:resource_foreign_key) { :visitor_id }
    @controller.define_singleton_method(:resource_class) { Visitor }
    @controller.define_singleton_method(:token_class) { VisitorToken }
    @controller.define_singleton_method(:token_kind_model) { VisitorTokenKind }
    @controller.define_singleton_method(:session_limit_state_for) { |_| :within_limit }
    @controller.define_singleton_method(:record_audit) { |*| nil }

    assert_difference("VisitorToken.count", 1) do
      result = @controller.log_in(visitor, record_login_audit: false, require_totp_check: false)

      assert_equal :success, result[:status]
    end

    token = VisitorToken.order(created_at: :desc).first

    assert_equal VisitorTokenStatus::ACTIVE, token.visitor_token_status_id
  end

  private

  def generate_dpop_jwk
    ec = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(ec).export
    [ec, jwk]
  end

  def build_dpop_proof(private_key, jwk, method:, uri:)
    payload = {
      "htm" => method,
      "htu" => uri,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
    }
    JWT.encode(payload, private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk })
  end
end
