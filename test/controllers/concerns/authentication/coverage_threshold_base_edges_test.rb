# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdBaseEdgeHarness < ApplicationController
  include AuthenticationBase

  attr_accessor :request_obj, :session_hash

  def initialize
    super
    @session_hash = {}
    @request_obj = ActionDispatch::TestRequest.create
    @request_obj.host = "auth.app.localhost"
    @request_obj.remote_ip = "127.0.0.1"
    @request_obj.request_method = "GET"
    @request_obj.format = Mime[:html]
    self.response = ActionDispatch::TestResponse.new
  end

  def request = @request_obj

  def session = @session_hash

  def resource_type = "client"

  def resource_class = Client

  def token_class = ClientToken

  def audit_class = ClientChronicle

  def resource_foreign_key = :user_id

  def sign_in_url_with_pt(_pt) = "/sign/in"

  def am_i_user? = true

  def am_i_operator? = false

  def am_i_owner? = false
end

class CoverageThresholdBaseEdgesTest < ActiveSupport::TestCase
  setup { @harness = CoverageThresholdBaseEdgeHarness.new }

  test "request and session fallback helpers cover blank inputs" do
    @harness.define_singleton_method(:request) { nil }

    assert_instance_of ActionController::Parameters, @harness.params
    @harness.define_singleton_method(:request) { @request_obj }
    @harness.session[AuthenticationBase::DEFAULT_PT_SESSION_KEY] = "/return"
    @harness.define_singleton_method(:t) { |_key| "expired" }
    redirected = []
    @harness.define_singleton_method(:redirect_to) { |*args| redirected << args }
    @harness.send(:handle_session_expiry, "/login", "expired")

    assert_equal "/return", redirected.last.last[AuthIoKeys::Params::PT]
    assert_not @harness.send(:resource_withdrawn?, Object.new)
    assert_not @harness.send(:resource_withdrawn?, nil)
  end

  test "resource and token reference tables cover every supported actor" do
    %w(client operator visitor unknown).each do |type|
      @harness.define_singleton_method(:resource_type) { type }

      assert_kind_of Hash, @harness.send(:login_token_reference_models)
      assert_kind_of Hash, @harness.send(:default_status_token_attributes)
      assert_kind_of Hash, @harness.send(:default_dbsc_token_attributes, nil)
      assert_kind_of Class, @harness.send(:token_kind_model) if type != "unknown"
    end

    assert_equal AppTicketRecord, @harness.send(:token_reference_connection_model, ClientTokenKind)
    assert_equal ComTicketRecord, @harness.send(:token_reference_connection_model, VisitorTokenKind)
    assert_equal OrgTicketRecord, @harness.send(:token_reference_connection_model, OperatorTokenKind)
  end

  test "DBSC payload and cookie helpers reject absent and unbound records" do
    assert_nil @harness.send(:dbsc_payload_for, nil)
    record = Object.new
    record.define_singleton_method(:binding_method_dbsc?) { false }

    assert_nil @harness.send(:dbsc_cookie_value_for, record)
    assert_nil @harness.send(:dbsc_cookie_expires_at_for, record)
    assert_nil @harness.send(:token_record_expiry_at, nil)
    assert_nil @harness.send(:token_record_expiry_at, Object.new)
    assert_equal 0, @harness.send(:expires_in_for, 1.minute.ago)
  end

  test "DBSC route helpers select primary compatibility and failure paths" do
    @harness.define_singleton_method(:auth_app_edge_v0_token_dbsc_path) { "/primary" }

    assert_equal "/primary",
                 @harness.send(:dbsc_route_helper, :auth_app_edge_v0_token_dbsc_path, :sign_app_edge_v0_token_dbsc_path)
    @harness.define_singleton_method(:respond_to?) do |name, include_private = false|
      return false if name.to_sym == :auth_app_edge_v0_token_dbsc_path

      super(name, include_private)
    end
    @harness.define_singleton_method(:sign_app_edge_v0_token_dbsc_path) { "/compat" }

    assert_equal "/compat",
                 @harness.send(:dbsc_route_helper, :auth_app_edge_v0_token_dbsc_path, :sign_app_edge_v0_token_dbsc_path)
    assert_raises(NoMethodError) { @harness.send(:dbsc_route_helper, :missing_primary, :missing_compat) }
  end

  test "transparent refresh and side effect helpers cover guard and rescue paths" do
    @harness.request_obj.set_header("REQUEST_METHOD", "POST")

    assert_not @harness.send(:transparent_refresh_allowed?)
    @harness.request_obj.set_header("REQUEST_METHOD", "GET")
    @harness.request_obj.define_singleton_method(:get?) { true }
    @harness.request_obj.define_singleton_method(:format) { Struct.new(:html?).new(true) }

    assert @harness.send(:transparent_refresh_allowed?)
    assert_nil @harness.send(:best_effort_refresh_side_effect) { raise RuntimeError, "side effect" }
    @harness.define_singleton_method(:refresh_access_token) { |value| { refresh: value } }

    assert_equal({ refresh: "token" }, @harness.send(:attempt_transparent_refresh!, "token"))
    assert @harness.request.env[AuthIoKeys::Env::AUTH_REFRESHED_FLAG]
  end

  test "MFA and pending-session guards cover invalid states" do
    assert_not @harness.send(:mfa_required_for?, Object.new)
    assert_not @harness.send(:pending_mfa_valid?)
    @harness.define_singleton_method(:controller_path) { "coverage_threshold_base_edge_harness" }
    @harness.session[:pending_mfa] = { expires_at: 5.minutes.from_now.to_i }

    assert_nil @harness.send(:pending_mfa_user)
    assert_equal "coverage_threshold_base_edge_harness.session", @harness.send(:session_limit_gate_flow)
    assert_equal "/", @harness.send(:session_limit_gate_pt)
  end

  test "current resource and policy helper fallbacks are explicit" do
    Actor.reset

    assert_nil @harness.send(:actor_current_resource)
    @harness.define_singleton_method(:logged_in?) { false }
    @harness.define_singleton_method(:request) { @request_obj }

    assert @harness.send(:enforce_authentication_guest!, request_format: :html)
    assert_raises(AuthenticationBase::MissingPolicyError) { @harness.send(:enforce_authentication_deny_all!) }
    assert_raises(AuthenticationBase::InvalidPolicyError) { @harness.send(:policy_for_authentication_mode, :unknown) }
  ensure
    Actor.reset
  end
end

class CoverageThresholdBaseEdgesTest
  test "session record and expiry validation cover missing and rejected records" do
    assert_not @harness.send(:validate_session_expiry, {})
    assert @harness.send(:validate_session_expiry, { other: 1 })
    record = Struct.new(:otp_expired, :user_email_status_id) do
      def otp_expired? = otp_expired
    end.new(false, "ACTIVE")
    model =
      Class.new do
        define_singleton_method(:includes) { |*| self }
        define_singleton_method(:find_by) { |**| record }
      end
    @harness.session[:record] = 9

    validation = { includes: :owner, status_id: "ACTIVE", custom: ->(r) { r == record } }

    assert_same record, @harness.send(
      :load_session_record, :record, model, validation,
    )

    record.otp_expired = true

    assert_nil @harness.send(:load_session_record, :record, model, check_otp_expiry: true)
    record.otp_expired = false

    assert_nil @harness.send(:load_session_record, :record, model, status_id: "REVOKED")
    assert_nil @harness.send(:load_session_record, :record, model, custom: ->(_) { false })
  end

  test "login guards and actor lock cover denied and transactional paths" do
    locked = Object.new
    locked.define_singleton_method(:login_allowed?) { true }
    @harness.define_singleton_method(:administratively_locked_resource?) { |_| true }

    assert_equal :access_locked, @harness.send(:log_in, locked)[:status]
    denied = Object.new
    denied.define_singleton_method(:login_allowed?) { false }
    @harness.define_singleton_method(:administratively_locked_resource?) { |_| false }

    assert_equal :login_forbidden, @harness.send(:log_in, denied)[:status]
    klass =
      Class.new do
        def self.connection_class? = true

        def self.connected_to(**) = yield

        def self.transaction = yield
      end
    actor = klass.new
    actor.define_singleton_method(:lock!) { true }

    assert_equal :done, @harness.send(:with_actor_session_lock, actor) { :done }
  end
end

class CoverageThresholdBaseEdgesTest
  test "authentication guard helpers exercise blank and alternate request paths" do
    assert_equal :unlocked, @harness.send(:with_actor_session_lock, nil) { :unlocked }

    @harness.define_singleton_method(:request) { nil }

    assert_nil @harness.send(:request_ip_address)
    assert_nil @harness.send(:load_current_resource)
    assert_nil @harness.send(:load_from_token)
    assert_not @harness.send(:transparent_refresh_allowed?)

    @harness.define_singleton_method(:request) { @request_obj }
    @harness.request_obj.host = ""

    assert_nil @harness.send(:load_from_token)
    assert_equal "/", @harness.send(:default_after_login_path)
  end

  test "inertia redirect conversion replaces redirect with conflict location" do
    @harness.request_obj.define_singleton_method(:inertia?) { true }
    @harness.response.status = 302
    @harness.response.headers["Location"] = "/sign/in"

    @harness.send(:convert_redirect_to_inertia_location!)

    assert_equal 409, @harness.response.status
    assert_equal "/sign/in", @harness.response.headers["X-Inertia-Location"]
    assert_nil @harness.response.headers["Location"]
  end

  test "refresh predicates reject absent and suspended resources deliberately" do
    assert_not @harness.send(:refreshable_resource?, nil, allow_suspended: true)
    suspended = Object.new
    suspended.define_singleton_method(:active?) { false }
    suspended.define_singleton_method(:suspended?) { true }

    assert @harness.send(:refreshable_resource?, suspended, allow_suspended: true)
    assert_not @harness.send(:refreshable_resource?, suspended, allow_suspended: false)

    token = Object.new
    token.define_singleton_method(:binding_method_nothing?) { false }
    token.define_singleton_method(:binding_method_legacy?) { false }

    assert_not @harness.send(:legacy_unbound_refresh_allowed?, token)
    token.define_singleton_method(:binding_method_nothing?) { true }
    token.define_singleton_method(:dbsc_status_nothing?) { true }

    assert @harness.send(:legacy_unbound_refresh_allowed?, token)
  end

  test "refresh binding guards cover revoked, verified, and missing proof sessions" do
    assert @harness.send(:device_session_refresh_allowed?, nil)
    session =
      Struct.new(:revoked, :bound) do
        def revoked? = revoked

        def dbsc_bound? = bound
      end
    record = Struct.new(:device_session).new(session.new(true, true))

    assert_not @harness.send(:device_session_refresh_allowed?, record)

    record.device_session = session.new(false, true)
    @harness.instance_variable_set(:@refresh_dbsc_verified, true)

    assert @harness.send(:device_session_refresh_allowed?, record)
    @harness.instance_variable_set(:@refresh_dbsc_verified, false)

    assert_not @harness.send(:device_session_refresh_allowed?, record)
    assert_equal "missing_proof", @harness.instance_variable_get(:@refresh_dbsc_reason)

    @harness.define_singleton_method(:device_session_refresh_allowed?) { |_token| true }
    @harness.define_singleton_method(:refresh_dbsc_allowed?) { |_token| false }
    @harness.define_singleton_method(:legacy_unbound_refresh_allowed?) { |_token| true }
    dbsc = Object.new
    dbsc.define_singleton_method(:binding_method_dbsc?) { true }

    assert_not @harness.send(:refresh_binding_allowed?, dbsc)
    legacy = Object.new
    legacy.define_singleton_method(:binding_method_dbsc?) { false }

    assert @harness.send(:refresh_binding_allowed?, legacy)
  end

  test "session and token helper fallbacks cover nil and non-string values" do
    assert_equal 123, @harness.send(:resolve_token_kind_id, 123)
    assert_nil @harness.send(:ensure_token_kind_exists!, nil)
    assert_in_delta 15.minutes, @harness.send(:restricted_session_expires_at) - Time.current, 2.seconds
    assert_nil @harness.send(:pending_mfa_user)
    @harness.session[:pending_mfa] = { expires_at: 1.minute.from_now.to_i }

    assert_nil @harness.send(:pending_mfa_user)
  end
end

class CoverageThresholdBaseEdgesTest
  test "authentication side-effect guards and redirect surface fallbacks are explicit" do
    model =
      Class.new do
        define_singleton_method(:find_by) { |**| nil }
      end
    @harness.session[:missing] = 1

    assert_nil @harness.send(:load_session_record, :missing, model)
    assert_nil @harness.send(:record_audit, nil, resource: nil)
    @harness.define_singleton_method(:occurrence_model_class) { nil }

    assert_nil @harness.send(
      :write_refresh_occurrence,
      event_type: "refresh_failed", token_record: nil, reason: "test", device_source: "none",
    )
    assert_nil @harness.send(:populate_current_attributes!, nil, nil)

    @harness.request_obj.define_singleton_method(:inertia?) { true }
    @harness.response.status = 200

    assert_nil @harness.send(:convert_redirect_to_inertia_location!)

    %w(base/app/thing base/com/thing auth/app/thing auth/com/thing other).each do |path|
      @harness.define_singleton_method(:controller_path) { path }
      @harness.define_singleton_method(:new_base_app_identity_withdrawal_session_path) { |**options| ["app", options] }
      @harness.define_singleton_method(:new_base_com_identity_withdrawal_session_path) { |**options| ["com", options] }

      assert_equal(path.include?("com") ? "com" : "app", @harness.send(:withdrawal_required_session_entry_path).first)
    end
  end

  test "authentication token guards return before persistence for rejected inputs" do
    @harness.define_singleton_method(:session_limit_state_for) { |_resource| :within_limit }
    @harness.define_singleton_method(:validate_login_dpop_proof) { { status: :invalid, error: "bad_proof" } }
    result = @harness.send(
      :issue_login_tokens_within_lock,
      Object.new,
      record_login_audit: false,
      token_kind_id: "BROWSER_WEB",
      audit_context: {},
      bootstrap_actor: false,
    )

    assert_equal :invalid, result[:status]

    @harness.define_singleton_method(:token_class) { Class.new { def self.parse_refresh_token(_); ["r-1"] end } }
    restricted = Object.new
    restricted.define_singleton_method(:restricted?) { true }
    @harness.define_singleton_method(:find_refresh_token_record) { |_id| restricted }
    @harness.define_singleton_method(:handle_restricted_refresh_rejected) { |*| :restricted }

    assert_equal :restricted, @harness.send(:refresh_access_token, "refresh")

    record = Object.new
    record.define_singleton_method(:restricted?) { false }
    @harness.define_singleton_method(:find_refresh_token_record) { |_id| record }
    @harness.define_singleton_method(:refresh_dpop_allowed?) { |_record| true }
    @harness.define_singleton_method(:refresh_binding_allowed?) { |_record| true }
    @harness.define_singleton_method(:refresh_idle_allowed?) { |_record| false }
    @harness.define_singleton_method(:handle_refresh_idle_timeout) { |*| :idle }

    assert_equal :idle, @harness.send(:refresh_access_token, "refresh")
  end
end

class CoverageThresholdBaseEdgesTest
  test "authentication mode and current-resource fallback branches are exercised" do
    klass = Class.new(CoverageThresholdBaseEdgeHarness)
    klass.define_singleton_method(:name) { "CoverageThresholdModeHarness" }
    assert_raises(AuthenticationBase::InvalidPolicyError) { klass.declare_authentication_mode!(:invalid) }
    klass.declare_authentication_mode!(:guest, except: :blocked)

    assert_equal :guest, klass.authentication_mode_for(:open)

    current = Object.new
    @harness.define_singleton_method(:load_from_token) { nil }
    @harness.define_singleton_method(:authentication_credentials_invalid?) { false }
    @harness.instance_variable_set(:@current_resource, current)

    assert_same current, @harness.send(:load_current_resource)

    @harness.instance_variable_set(:@current_resource, nil)
    @harness.define_singleton_method(:resource_withdrawn?) { |resource| resource.nil? }

    assert_nil @harness.send(:load_current_resource)

    user = Object.new
    @harness.define_singleton_method(:resource_withdrawn?) { |resource| resource.equal?(user) }
    @harness.define_singleton_method(:controller_path) { "auth/app/sign/in" }
    @harness.define_singleton_method(:transparent_refresh_allowed?) { true }
    @harness.define_singleton_method(:cookies) { { AuthenticationBase::REFRESH_COOKIE_KEY => "refresh" } }
    @harness.define_singleton_method(:attempt_transparent_refresh!) { |_plain| { user: user } }

    assert_nil @harness.send(:load_current_resource)
  end
end

class CoverageThresholdBaseEdgesTest
  test "authentication fallback helpers cover cookie, session, and MFA edges" do
    @harness.define_singleton_method(:cookies) { {} }

    assert_nil @harness.send(:destroy_refresh_token_from_cookie)
    @harness.define_singleton_method(:cookies) { { AuthenticationBase::REFRESH_COOKIE_KEY => "raw" } }
    token_class = Class.new
    token_class.define_singleton_method(:parse_refresh_token) { |_value| [nil] }
    @harness.define_singleton_method(:token_class) { token_class }

    assert_nil @harness.send(:destroy_refresh_token_from_cookie)

    @harness.define_singleton_method(:respond_to?) do |name, include_private = false|
      return false if %i(auth_app_root_path auth_org_root_path).include?(name.to_sym)

      super(name, include_private)
    end

    assert_equal "/", @harness.send(:default_after_login_path)

    %w(visitor operator client unknown).each do |type|
      @harness.define_singleton_method(:resource_type) { type }
      attrs = @harness.send(:scheduled_login_token_attributes, now: Time.current)
      if %w(visitor operator).include?(type)
        assert_includes attrs.keys, :discarded_at
      else
        assert_empty attrs
      end
    end

    client = Client.allocate
    client.define_singleton_method(:mfa_level_required?) { false }

    assert_not @harness.send(:mfa_required_for?, client)
    client.define_singleton_method(:mfa_level_required?) { true }

    assert @harness.send(:mfa_required_for?, client)
    operator = Operator.allocate
    operator.define_singleton_method(:mfa_level_required?) { true }
    operator.define_singleton_method(:mfa_level_enabled?) { true }

    assert @harness.send(:mfa_required_for?, operator)

    assert_nil @harness.send(:issue_dbsc_registration_header_for, nil)
    bound = Object.new
    bound.define_singleton_method(:binding_method_dbsc?) { true }

    assert_nil @harness.send(:issue_dbsc_registration_header_for, bound)
  end
end
