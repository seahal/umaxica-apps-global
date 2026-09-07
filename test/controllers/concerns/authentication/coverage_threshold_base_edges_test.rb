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
