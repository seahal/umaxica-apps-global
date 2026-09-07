# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdBaseAuthHarness < ApplicationController
  include AuthenticationBase

  attr_accessor :session_hash, :request_obj

  def initialize
    super
    @session_hash = {}
    @request_obj = ActionDispatch::TestRequest.create
    @request_obj.host = "auth.app.localhost"
    @request_obj.remote_ip = "127.0.0.1"
    self.request = @request_obj
    self.response = ActionDispatch::TestResponse.new
  end

  def session = @session_hash

  def resource_type = @resource_type || "client"

  def resource_type=(value)
    @resource_type = value
  end

  def resource_class = Client

  def token_class = ClientToken

  def audit_class = ClientChronicle

  def resource_foreign_key = :user_id

  def sign_in_url_with_pt(_pt) = "/sign/in"

  def am_i_user? = true

  def am_i_operator? = false

  def am_i_owner? = false
end

class CoverageThresholdBaseAuthTest < ActiveSupport::TestCase
  setup { @controller = CoverageThresholdBaseAuthHarness.new }

  test "pending MFA validity distinguishes expiry and issuance timestamps" do
    assert_not @controller.send(:pending_mfa_valid?)
    @controller.session[:pending_mfa] = { expires_at: 1.minute.from_now.to_i }

    assert @controller.send(:pending_mfa_valid?)
    @controller.session[:pending_mfa] = { expires_at: 1.minute.ago.to_i }

    assert_not @controller.send(:pending_mfa_valid?)
    @controller.session[:pending_mfa] = { issued_at: 1.minute.ago.to_i }

    assert @controller.send(:pending_mfa_valid?)
    @controller.session[:pending_mfa] = { issued_at: 11.minutes.ago.to_i }

    assert_not @controller.send(:pending_mfa_valid?)
    @controller.session[:pending_mfa] = { issued_at: 0 }

    assert_not @controller.send(:pending_mfa_valid?)
  end

  test "token status and DBSC defaults dispatch by resource and browser kind" do
    { "client" => ClientTokenKind::BROWSER_WEB,
      "operator" => OperatorTokenKind::BROWSER_WEB,
      "visitor" => VisitorTokenKind::BROWSER_WEB, }.each do |type, browser_kind|
      @controller.resource_type = type
      status = @controller.send(:default_status_token_attributes)

      assert_equal 1, status.values.first
      pending = @controller.send(:default_dbsc_token_attributes, browser_kind)

      assert_equal 2, pending.values.last
      nothing = @controller.send(:default_dbsc_token_attributes, "CLIENT_IOS")

      assert_not_equal pending.values.last, nothing.values.last
      assert @controller.send(:dbsc_registration_eligible_kind?, browser_kind)
      assert_not @controller.send(:dbsc_registration_eligible_kind?, nil)
    end
    @controller.resource_type = "unknown"

    assert_empty @controller.send(:default_status_token_attributes)
    assert_empty @controller.send(:default_dbsc_token_attributes, "BROWSER_WEB")
    assert_not @controller.send(:dbsc_registration_eligible_kind?, "BROWSER_WEB")
  end

  test "DBSC binding and status names cover every lifecycle arm" do
    record = Object.new
    record.define_singleton_method(:binding_method_dbsc?) { true }
    record.define_singleton_method(:binding_method_legacy?) { false }
    record.define_singleton_method(:dbsc_status_pending?) { true }
    record.define_singleton_method(:dbsc_status_active?) { false }
    record.define_singleton_method(:dbsc_status_failed?) { false }
    record.define_singleton_method(:dbsc_status_revoke?) { false }

    assert_equal "dbsc", @controller.send(:dbsc_binding_method_name, record)
    assert_equal "pending", @controller.send(:dbsc_status_name, record)
    record.define_singleton_method(:binding_method_dbsc?) { false }
    record.define_singleton_method(:binding_method_legacy?) { true }

    assert_equal "legacy", @controller.send(:dbsc_binding_method_name, record)
    %i(active failed revoke).each do |state|
      record.define_singleton_method(:dbsc_status_pending?) { false }
      record.define_singleton_method(:dbsc_status_active?) { state == :active }
      record.define_singleton_method(:dbsc_status_failed?) { state == :failed }
      record.define_singleton_method(:dbsc_status_revoke?) { state == :revoke }

      assert_equal state.to_s, @controller.send(:dbsc_status_name, record)
    end
    record.define_singleton_method(:binding_method_legacy?) { false }

    assert_equal "nothing", @controller.send(:dbsc_binding_method_name, record)
    record.define_singleton_method(:dbsc_status_active?) { false }
    record.define_singleton_method(:dbsc_status_failed?) { false }
    record.define_singleton_method(:dbsc_status_revoke?) { false }

    assert_equal "nothing", @controller.send(:dbsc_status_name, record)
  end

  test "refresh sources and expiry helpers cover nil, infinite, and finite inputs" do
    assert_equal "none", @controller.send(:refresh_dbsc_source)
    @controller.request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = "sid"

    assert_equal "session_id", @controller.send(:refresh_dbsc_source)
    @controller.request.headers[AuthIoKeys::Headers::DBSC_RESPONSE] = "proof"

    assert_equal "both", @controller.send(:refresh_dbsc_source)
    @controller.request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID] = ""

    assert_equal "response", @controller.send(:refresh_dbsc_source)
    assert_equal 1, @controller.send(:epoch_seconds, 1)
    assert_equal 1, @controller.send(:epoch_seconds, 1.second)
    assert_operator @controller.send(:epoch_seconds, 1.second.from_now), :>, 0
    assert_equal 0, @controller.send(:epoch_seconds, "not-a-number")
    assert_equal :expired_at, @controller.send(
      :token_expiry_column, Class.new {
                              def self.column_names
                                ["expired_at"]
                              end
                            },
    )
    assert_equal :revoked_at, @controller.send(
      :token_expiry_column, Class.new {
                              def self.column_names
                                ["revoked_at"]
                              end
                            },
    )
  end

  test "refresh idle and resource token helpers cover fallback types" do
    assert @controller.send(:refresh_idle_allowed?, nil)
    token = Struct.new(:last_used_at, :created_at) do
      def has_attribute?(_name) = true
    end.new(nil, nil)

    assert @controller.send(:refresh_idle_allowed?, token)
    token.last_used_at = 2.days.ago

    assert_not @controller.send(:refresh_idle_allowed?, token)
    assert_equal ClientToken, @controller.send(:token_class_for_resource, clients(:one))
    assert_equal OperatorToken, @controller.send(:token_class_for_resource, operators(:one))
    assert_equal ClientToken, @controller.send(:token_class_for_resource, Object.new)
    assert_equal({ user_id: 1 }, @controller.send(:risk_actor_payload, 1))
    @controller.resource_type = "operator"

    assert_equal({ staff_id: 1 }, @controller.send(:risk_actor_payload, 1))
    @controller.resource_type = "visitor"

    assert_equal({ visitor_id: 1 }, @controller.send(:risk_actor_payload, 1))
  end
end
