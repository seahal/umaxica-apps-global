# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationVisitorCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthenticationVisitor

    attr_accessor :current_resource, :audit_calls

    def initialize
      super
      @audit_calls = []
    end

    def record_audit(*args, **kwargs)
      @audit_calls << [args, kwargs]
      super
    end
  end

  test "visitor predicates and resource mapping match the visitor surface" do
    harness = Harness.new
    visitor = Visitor.new
    visitor.define_singleton_method(:active?) { true }
    harness.current_resource = visitor

    assert_equal visitor, harness.current_visitor
    assert_predicate harness, :active_visitor?
    assert_not harness.am_i_user?
    assert_not harness.am_i_staff?
    assert_not harness.am_i_owner?
    assert_equal Visitor, harness.send(:resource_class)
    assert_equal VisitorToken, harness.send(:token_class)
    assert_equal ClientChronicle, harness.send(:audit_class)
    assert_equal "visitor", harness.send(:resource_type)
    assert_equal :visitor_id, harness.send(:resource_foreign_key)
    assert_equal VisitorToken::MAX_SESSIONS_PER_VISITOR, harness.send(:max_sessions_for_resource, visitor)
  end

  test "audit_visitor_login_failed records a login-failed event for a present visitor" do
    harness = Harness.new
    visitor = Visitor.new
    recorded = []
    harness.define_singleton_method(:record_audit) { |event, **kwargs| recorded << [event, kwargs] }

    harness.audit_visitor_login_failed(nil)
    harness.audit_visitor_login_failed(visitor)

    assert_equal 1, recorded.size
    assert_equal AuthenticationVisitor::AUDIT_EVENTS[:login_failed], recorded.first.first
    assert_nil recorded.first.last[:actor]
  end

  test "record_audit maps named events and swallows write failures as a logged false" do
    harness = Harness.new
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING) if defined?(VisitorMfaLevel)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED) if defined?(VisitorMfaStatus)
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    harness.define_singleton_method(:request_ip_address) { "127.0.0.1" }

    assert harness.send(:record_audit, "LOGIN_FAILED", resource: visitor, actor: visitor)
    assert_nil harness.send(:record_audit, nil, resource: visitor)

    ChronicleRecord.stub(:connected_to, ->(*) { raise StandardError, "write failed" }) do
      assert_equal false, harness.send(:record_audit, "TOKEN_REFRESHED", resource: visitor)
    end
  end

  test "sign_in_url_with_pt uses the current host when it is an allowed corporate auth host" do
    harness = Harness.new
    host = CommonRedirect.normalize_host(ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"))
    request = Struct.new(:host_with_port).new(host)
    harness.define_singleton_method(:request) { request }
    captured = {}
    harness.define_singleton_method(:auth_com_sign_in_url) do |**kwargs|
      captured.replace(kwargs)
      "https://#{kwargs[:host]}/sign-in"
    end

    url = harness.send(:sign_in_url_with_pt, "/return")

    assert_equal host, captured[:host]
    assert_equal "https", captured[:protocol]
    assert_includes url, host
  end
end
