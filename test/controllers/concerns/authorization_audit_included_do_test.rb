# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AuthorizationAuditIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthorizationAudit
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
