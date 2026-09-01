# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthorizationAuditIncludedDoTest < ActiveSupport::TestCase
  fixtures :visitors

  class Harness < ApplicationController
    include AuthorizationAudit
  end

  # The audit actor comes from the Actor context when it agrees with the legacy
  # per-surface reader, and is rejected when it is absent, the unauthenticated
  # singleton, or a different actor than the request resolved.
  # The audit actor prefers the Actor context when it is authenticated and agrees
  # with the per-surface reader; otherwise the legacy reader stands.
  # An authorization failure is recorded against whichever actor kind raised it. The
  # visitor arm had no test, and neither did the guard that keeps an unknown actor
  # from writing a row at all.
  test "create_audit_record routes a visitor failure to the visitor writer" do
    harness = Harness.new
    routed = []
    harness.define_singleton_method(:create_user_authorization_audit) { |a, _| routed << [:client, a] }
    harness.define_singleton_method(:create_staff_authorization_audit) { |a, _| routed << [:operator, a] }
    harness.define_singleton_method(:create_visitor_authorization_audit) { |a, _| routed << [:visitor, a] }

    visitor = Visitor.new
    harness.send(:create_audit_record, visitor, {})

    assert_equal [[:visitor, visitor]], routed

    harness.send(:create_audit_record, Object.new, {})

    assert_equal 1, routed.size, "an actor of no known kind must not write an audit row"
  end

  test "create_visitor_authorization_audit records the failure against the visitor" do
    harness = Harness.new
    visitor = visitors(:reserved_visitor)
    log_data = {
      ip_address: "203.0.113.9",
      timestamp: Time.current,
      request_id: "req-9",
      trace_id: "trace-9",
    }

    assert_difference -> { ClientChronicle.where(actor_type: "Visitor", actor_id: visitor.id).count }, 1 do
      harness.send(:create_visitor_authorization_audit, visitor, log_data)
    end

    audit = ClientChronicle.where(actor_type: "Visitor", actor_id: visitor.id).order(:id).last

    assert_equal ClientChronicleEvent::AUTHORIZATION_FAILED, audit.event_id
    assert_equal visitor.id.to_s, audit.subject_id
  end

  test "authorization_audit_actor prefers an agreeing Actor context over the legacy reader" do
    harness = Harness.new
    actor = Object.new
    harness.define_singleton_method(:current_client_or_staff) { actor }

    Actor.stub(:authenticated?, true) do
      Actor.stub(:actor, actor) do
        assert_equal actor, harness.send(:authorization_audit_actor)
      end

      Actor.stub(:actor, Object.new) do
        assert_equal actor, harness.send(:authorization_audit_actor)
      end
    end

    Actor.stub(:authenticated?, false) do
      assert_equal actor, harness.send(:authorization_audit_actor)
    end
  end

  test "usable_authorization_audit_actor? rejects a blank, unauthenticated or mismatched actor" do
    harness = Harness.new
    actor = Object.new
    other = Object.new

    assert_not harness.send(:usable_authorization_audit_actor?, nil, actor)
    assert_not harness.send(:usable_authorization_audit_actor?, Unauthenticated.instance, actor)
    assert harness.send(:usable_authorization_audit_actor?, actor, nil)
    assert harness.send(:usable_authorization_audit_actor?, actor, actor)
    assert_not harness.send(:usable_authorization_audit_actor?, actor, other)
  end

  test "audit_identifier prefers the public id and falls back to the primary key" do
    harness = Harness.new
    with_public_id = Struct.new(:public_id, :id).new("pub-1", 7)
    blank_public_id = Struct.new(:public_id, :id).new(nil, 9)
    id_only = Struct.new(:id).new(11)

    assert_nil harness.send(:audit_identifier, nil)
    assert_equal "pub-1", harness.send(:audit_identifier, with_public_id)
    assert_equal 9, harness.send(:audit_identifier, blank_public_id)
    assert_equal 11, harness.send(:audit_identifier, id_only)
  end

  test "included do includes CommonRedirect module" do
    assert_includes Harness.included_modules, CommonRedirect,
                    "Harness should include CommonRedirect"
  end

  test "handle_authorization_error method exists (private)" do
    Harness.new

    assert_includes AuthorizationAudit.private_instance_methods(false), :handle_authorization_error,
                    "AuthorizationAudit should have private method handle_authorization_error"
  end

  test "log_authorization_failure method exists (private)" do
    assert_includes AuthorizationAudit.private_instance_methods(false), :log_authorization_failure,
                    "AuthorizationAudit should have private method log_authorization_failure"
  end

  test "build_log_data method exists (private)" do
    assert_includes AuthorizationAudit.private_instance_methods(false), :build_log_data,
                    "AuthorizationAudit should have private method build_log_data"
  end

  test "create_audit_record method exists (private)" do
    assert_includes AuthorizationAudit.private_instance_methods(false), :create_audit_record,
                    "AuthorizationAudit should have private method create_audit_record"
  end

  test "current_user_or_staff method exists (private)" do
    assert_includes AuthorizationAudit.private_instance_methods(false), :current_user_or_staff,
                    "AuthorizationAudit should have private method current_user_or_staff"
  end

  test "safe_redirect_back_or_to method available via included CommonRedirect" do
    harness = Harness.new

    assert_includes harness.private_methods, :safe_redirect_back_or_to,
                    "safe_redirect_back_or_to should be a private method"
  end
end
