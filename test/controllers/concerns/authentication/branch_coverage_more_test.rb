# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationBaseBranchCoverageMoreTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthenticationBase

    attr_accessor :resource_type_value, :request_value, :session_value

    def resource_type = resource_type_value || "client"

    def resource_class = Client

    def token_class = ClientToken

    def audit_class = ClientChronicle

    def resource_foreign_key = :user_id

    def request = request_value

    def session = session_value || {}

    def am_i_user? = true

    def am_i_operator? = false

    def am_i_owner? = false
  end

  test "authentication mode and filter guards skip ineligible rules" do
    klass = Class.new(Harness)
    klass.declare_authentication_mode!(:guest, only: :allowed)

    assert_includes %i(deny_all unexpected), klass.authentication_mode_for(:other)
    klass.skip_before_action({ enforce_access_policy!: true })
    assert_raises(AuthenticationBase::SkipNotAllowedError) { klass.skip_action_callback(:process_action, :before, :enforce_access_policy!) }
  end

  test "refresh binding, idle, and restricted ttl fallbacks are exercised" do
    h = Harness.new
    token = Struct.new(:last_used_at, :created_at, :device_session).new(nil, Time.current, nil)
    token.define_singleton_method(:has_attribute?) { |_name| true }

    assert h.send(:refresh_idle_allowed?, token)
    device = Struct.new(:revoked).new(false)
    device.define_singleton_method(:has_attribute?) { |_name| true }
    def device.revoked? = revoked
    token.device_session = device
    h.define_singleton_method(:device_session_refresh_allowed?) { |_t| false }

    assert_not h.send(:refresh_binding_allowed?, token)
    h.define_singleton_method(:token_class) { Class.new }

    assert_in_delta 15.minutes, h.send(:restricted_session_expires_at) - Time.current, 2.seconds
  end

  test "revoke fallback calls a bare token revoke method" do
    h = Harness.new
    klass =
      Class.new do
        def self.transaction = yield
      end
    token = klass.new
    token.define_singleton_method(:respond_to?) { |name, *| name.to_sym == :revoke! || super(name) }
    token.define_singleton_method(:revoked?) { false }
    revoked = false
    token.define_singleton_method(:revoke!) { revoked = true }
    token.define_singleton_method(:class) { klass }
    h.send(:revoke_refresh_session_after_dbsc_failure!, token)

    assert revoked
  end

  test "reference fallback and mfa pending user use safe defaults" do
    h = Harness.new
    model =
      Class.new do
        def self.connected_to(...) = yield

        def self.find_or_create_by!(**kwargs) = kwargs
      end
    h.define_singleton_method(:login_token_reference_models) { { user_token_binding_method_id: model } }
    h.send(:ensure_login_token_reference_data!, user_token_binding_method_id: 3)
    h.session_value = { pending_mfa: { expires_at: 1.minute.from_now.to_i, user_id: 1 } }

    Client.stub(:find_by, :found) { assert_equal :found, h.send(:pending_mfa_user) }
  end

  test "request and token fallbacks cover blank network and dbsc challenge" do
    h = Harness.new
    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    h.request_value = request
    device = Object.new
    device.define_singleton_method(:has_attribute?) { |_name| false }
    token = Struct.new(:device_session).new(device)

    assert_nil h.send(:detect_session_network_change!, token, Struct.new(:id).new(1))
    h.define_singleton_method(:issue_dbsc_challenge_for!) { |_record| nil }
    token.define_singleton_method(:binding_method_dbsc?) { false }
    h.response = ActionDispatch::TestResponse.new

    assert_nil h.send(:issue_dbsc_registration_header_for, token)
  end

  test "policy and expiry fallback branches return explicit values" do
    h = Harness.new
    h.class.define_singleton_method(:authentication_mode_for) { |_action| :unexpected }
    h.define_singleton_method(:policy_for_authentication_mode) { |_mode| :policy }
    assert_raises(AuthenticationBase::InvalidPolicyError) { h.send(:enforce_access_policy!) }
    h.define_singleton_method(:logged_in?) { true }

    assert h.send(:enforce_authentication_private!, {})
    plain = Object.new
    plain.define_singleton_method(:revoked_at) { Time.current }

    assert_in_delta 0, h.send(:token_record_expiry_at, plain) - plain.revoked_at, 0.1
    exception = Struct.new(:record).new(Object.new)

    assert_not h.send(:concurrent_session_limit_validation_error?, exception)
  end

  test "destroy refresh token handles a parsed id without current resource" do
    h = Harness.new
    h.define_singleton_method(:cookies) { { AuthenticationBase::REFRESH_COOKIE_KEY => "raw" } }
    klass =
      Class.new do
        def self.parse_refresh_token(*) = ["session-1"]
      end
    h.define_singleton_method(:token_class) { klass }
    called = []
    AuthenticationLogoutCurrentSession.stub(:call, ->(**kwargs) { called << kwargs }) do
      h.send(:destroy_refresh_token_from_cookie)
    end

    assert_equal "session-1", called.first[:session_public_id]
    assert_nil called.first[:resource]
  end
end
